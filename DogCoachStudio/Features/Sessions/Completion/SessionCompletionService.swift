import CryptoKit
import Foundation
import SwiftData

@MainActor
final class SessionCompletionService {
    private let context: ModelContext
    private let clock: any AppClock
    private let uuid: any UUIDGenerating
    var failurePoint: CompletionFailurePoint = .none

    init(context: ModelContext, clock: any AppClock, uuid: any UUIDGenerating) {
        self.context = context
        self.clock = clock
        self.uuid = uuid
    }

    func preview(_ request: PersistentCompletionRequest) throws -> CompletionPreview {
        let source = try validatedSource(for: request, acceptsCompletedSession: false)
        return CompletionPreview(
            sessionID: request.sessionID,
            attendeeCount: source.attended.count,
            exerciseCount: source.exercises.count,
            resultCount: source.attended.count * source.exercises.count,
            reportCount: source.attended.count,
            packages: source.bookings.map { booking in
                guard request.attendanceByBookingID[booking.id] == .attended else {
                    return PackagePreview(bookingID: booking.id, packageID: booking.expectedPackageID, balanceBefore: nil, policy: .skip)
                }
                guard let package = booking.expectedPackage else {
                    return PackagePreview(bookingID: booking.id, packageID: nil, balanceBefore: nil, policy: .skip)
                }
                let balance = package.initialUnits + (package.ledgerEntries ?? []).reduce(Decimal.zero) { $0 + $1.unitDelta }
                return PackagePreview(bookingID: booking.id, packageID: package.id, balanceBefore: balance, policy: balance > 0 ? .redeem : .insufficientBalance)
            }
        )
    }

    func complete(_ request: PersistentCompletionRequest) throws -> PersistentCompletionResult {
        let fingerprint = Self.fingerprint(request)
        if let replay = try completion(token: request.completionToken) {
            guard replay.requestFingerprint == fingerprint else { throw PersistentCompletionError.tokenPayloadConflict }
            return try result(for: replay)
        }
        if try activeCompletion(sessionID: request.sessionID) != nil { throw PersistentCompletionError.sessionAlreadyCompleted }
        let source = try validatedSource(for: request, acceptsCompletedSession: false)
        return try commit(request: request, source: source, revision: 1, supersedes: nil, correctionReason: nil, reversals: [])
    }

    func correct(_ request: SessionCorrectionRequest) throws -> PersistentCompletionResult {
        let reason = request.reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reason.isEmpty else { throw PersistentCompletionError.correctionReasonRequired }
        let correctionFingerprint = Self.correctionFingerprint(request, normalizedReason: reason)
        if let replay = try completion(token: request.completionToken) {
            guard replay.requestFingerprint == correctionFingerprint else { throw PersistentCompletionError.tokenPayloadConflict }
            return try result(for: replay)
        }
        guard let original = try context.fetch(FetchDescriptor<CompletedSessionRecord>()).first(where: { $0.id == request.originalCompletedSessionID && $0.isActiveRevision }) else {
            throw PersistentCompletionError.originalCompletionNotFound
        }

        let bookings = try bookings(sessionID: original.sessionID)
        let bookingIDs = Set(bookings.map(\.id))
        let originalAttendances = try context.fetch(FetchDescriptor<AttendanceRecord>()).filter {
            $0.completionRevision == original.revision && bookingIDs.contains($0.bookingID)
        }
        var attendance = Dictionary(uniqueKeysWithValues: originalAttendances.compactMap { record in
            SessionAttendanceStatus(rawValue: record.statusRawValue).map { (record.bookingID, $0) }
        })
        let snapshots = try context.fetch(FetchDescriptor<ExerciseSnapshotRecord>()).filter { $0.completedSessionID == original.id }
        let oldResults = try context.fetch(FetchDescriptor<DogExerciseResultRecord>())
        var overrides: [CompletionOutcomeOverride] = []
        for record in oldResults {
            guard let oldAttendance = originalAttendances.first(where: { $0.id == record.attendanceID }),
                  let snapshot = snapshots.first(where: { $0.id == record.exerciseSnapshotID }),
                  let outcome = ExerciseOutcome(rawValue: record.outcomeRawValue) else { continue }
            overrides.append(.init(bookingID: oldAttendance.bookingID, exerciseVersionID: snapshot.sourceExerciseVersionID, outcome: outcome))
        }
        for change in request.changes {
            switch change {
            case .attendance(let bookingID, let status): attendance[bookingID] = status
            case .outcome(let bookingID, let exerciseVersionID, let outcome):
                overrides.removeAll { $0.bookingID == bookingID && $0.exerciseVersionID == exerciseVersionID }
                overrides.append(.init(bookingID: bookingID, exerciseVersionID: exerciseVersionID, outcome: outcome))
            }
        }
        let revised = PersistentCompletionRequest(
            sessionID: original.sessionID,
            completionToken: request.completionToken,
            attendanceByBookingID: attendance,
            defaultOutcome: ExerciseOutcome(rawValue: original.defaultOutcomeRawValue) ?? .independent,
            overrides: overrides
        )
        let source = try validatedSource(for: revised, acceptsCompletedSession: true)
        let originalAttendanceIDs = Set(originalAttendances.map(\.id))
        let redeems = try context.fetch(FetchDescriptor<PackageLedgerEntryRecord>()).filter {
            $0.kindRawValue == "redeem" && $0.attendanceID.map(originalAttendanceIDs.contains) == true && $0.reversesEntryID == nil
        }
        original.isActiveRevision = false
        originalAttendances.forEach { $0.isActiveRevision = false }
        return try commit(request: revised, source: source, revision: original.revision + 1, supersedes: original, correctionReason: reason, reversals: redeems, fingerprint: correctionFingerprint)
    }

    private func commit(
        request: PersistentCompletionRequest,
        source: Source,
        revision: Int,
        supersedes: CompletedSessionRecord?,
        correctionReason: String?,
        reversals: [PackageLedgerEntryRecord],
        fingerprint: String? = nil
    ) throws -> PersistentCompletionResult {
        do {
            let now = clock.now()
            let completed = CompletedSessionRecord(id: uuid.makeUUID(), sessionID: request.sessionID, completedAt: now, completionToken: request.completionToken, revision: revision)
            completed.requestFingerprint = fingerprint ?? Self.fingerprint(request)
            completed.defaultOutcomeRawValue = request.defaultOutcome.rawValue
            completed.supersedesCompletedSessionID = supersedes?.id
            completed.correctionReason = correctionReason
            completed.session = source.session
            context.insert(completed)

            for entry in reversals {
                let reversal = PackageLedgerEntryRecord(id: uuid.makeUUID(), packageID: entry.packageID, kindRawValue: "reversal", unitDelta: -entry.unitDelta, createdAt: now)
                reversal.reversesEntryID = entry.id
                reversal.reversesEntry = entry
                reversal.reason = correctionReason
                reversal.package = entry.package
                context.insert(reversal)
            }

            let snapshots = source.exercises.map { exercise -> ExerciseSnapshotRecord in
                let snapshot = ExerciseSnapshotRecord(id: uuid.makeUUID(), completedSessionID: completed.id, sourceExerciseID: exercise.exerciseID, sourceExerciseVersionID: exercise.versionID)
                snapshot.localeIdentifier = exercise.locale.localeIdentifier
                snapshot.title = exercise.locale.title
                snapshot.goal = exercise.locale.goal
                snapshot.setup = exercise.locale.setup
                snapshot.steps = exercise.locale.steps
                snapshot.successCriteria = exercise.locale.successCriteria
                snapshot.homework = exercise.locale.homework
                snapshot.safetyNotes = exercise.locale.safetyNotes
                snapshot.completedSession = completed
                context.insert(snapshot)
                return snapshot
            }
            completed.exerciseSnapshots = snapshots

            var attendanceRecords: [AttendanceRecord] = []
            for booking in source.bookings {
                let status = request.attendanceByBookingID[booking.id]!
                let attendanceRecord = AttendanceRecord(id: uuid.makeUUID(), bookingID: booking.id, statusRawValue: status.rawValue, checkedAt: now)
                attendanceRecord.completionRevision = revision
                attendanceRecord.booking = booking
                attendanceRecord.packagePolicyRawValue = packagePolicy(for: booking, status: status).rawValue
                context.insert(attendanceRecord)
                attendanceRecords.append(attendanceRecord)
                guard status == .attended else { continue }

                let results = snapshots.map { snapshot -> DogExerciseResultRecord in
                    let result = DogExerciseResultRecord(id: uuid.makeUUID(), attendanceID: attendanceRecord.id, exerciseSnapshotID: snapshot.id)
                    result.outcomeRawValue = request.overrides.first { $0.bookingID == booking.id && $0.exerciseVersionID == snapshot.sourceExerciseVersionID }?.outcome.rawValue ?? request.defaultOutcome.rawValue
                    result.attendance = attendanceRecord
                    result.exerciseSnapshot = snapshot
                    context.insert(result)
                    return result
                }
                attendanceRecord.results = results

                if let package = booking.expectedPackage {
                    let redeem = PackageLedgerEntryRecord(id: uuid.makeUUID(), packageID: package.id, kindRawValue: "redeem", unitDelta: -1, createdAt: now)
                    redeem.attendanceID = attendanceRecord.id
                    redeem.attendance = attendanceRecord
                    redeem.package = package
                    context.insert(redeem)
                    attendanceRecord.ledgerEntries = [redeem]
                }

                let report = ClientReportRecord(id: uuid.makeUUID(), dogID: booking.dogID, completedSessionID: completed.id, localeIdentifier: Locale.current.identifier)
                report.revision = revision
                report.supersedesReportID = try previousReportID(dogID: booking.dogID, completion: supersedes)
                report.generatedAt = now
                report.body = results.map { result in
                    let title = snapshots.first { $0.id == result.exerciseSnapshotID }?.title ?? ""
                    return "\(title): \(result.outcomeRawValue)"
                }.joined(separator: "\n")
                report.dog = booking.dog
                report.completedSession = completed
                context.insert(report)
            }
            completed.reports = try context.fetch(FetchDescriptor<ClientReportRecord>()).filter { $0.completedSessionID == completed.id }
            source.session.statusRawValue = ScheduledSessionStatus.completed.rawValue
            source.session.completedSession = completed

            if failurePoint == .beforeSave { throw PersistentCompletionError.injectedFailure }
            try context.save()
            return try result(for: completed)
        } catch {
            context.rollback()
            throw error
        }
    }

    private struct ExerciseSource {
        let exerciseID: UUID
        let versionID: UUID
        let locale: ExerciseLocalizationRecord
    }
    private struct Source {
        let session: ScheduledSessionRecord
        let bookings: [BookingRecord]
        let attended: [BookingRecord]
        let exercises: [ExerciseSource]
    }

    private func validatedSource(for request: PersistentCompletionRequest, acceptsCompletedSession: Bool) throws -> Source {
        guard let session = try context.fetch(FetchDescriptor<ScheduledSessionRecord>()).first(where: { $0.id == request.sessionID }) else { throw PersistentCompletionError.sessionNotFound }
        let status = ScheduledSessionStatus(rawValue: session.statusRawValue) ?? .draft
        guard status == .inProgress || (acceptsCompletedSession && status == .completed) else { throw PersistentCompletionError.sessionNotReady }
        let bookings = try bookings(sessionID: request.sessionID).filter { $0.bookingStatusRawValue == SessionBookingStatus.booked.rawValue }
        let ids = Set(bookings.map(\.id))
        for id in request.attendanceByBookingID.keys where !ids.contains(id) { throw PersistentCompletionError.unknownBooking(id) }
        for id in ids where request.attendanceByBookingID[id] == nil { throw PersistentCompletionError.missingAttendance(id) }
        guard let template = session.templateVersion else { throw PersistentCompletionError.templateMissing }
        let templateItems = (template.exercises ?? []).sorted { $0.sortOrder < $1.sortOrder }
        guard !templateItems.isEmpty else { throw PersistentCompletionError.templateHasNoExercises }
        let versionIDs = Set(templateItems.map(\.exerciseVersionID))
        guard request.overrides.allSatisfy({ ids.contains($0.bookingID) && versionIDs.contains($0.exerciseVersionID) && request.attendanceByBookingID[$0.bookingID] == .attended }) else {
            throw PersistentCompletionError.unknownOverride
        }
        let allVersions = try context.fetch(FetchDescriptor<ExerciseVersionRecord>())
        let exercises = try templateItems.map { item -> ExerciseSource in
            guard let version = allVersions.first(where: { $0.id == item.exerciseVersionID }),
                  let locale = preferredLocalization(version.localizations ?? []) else { throw PersistentCompletionError.templateHasNoExercises }
            return ExerciseSource(exerciseID: version.exerciseID, versionID: version.id, locale: locale)
        }
        return Source(session: session, bookings: bookings, attended: bookings.filter { request.attendanceByBookingID[$0.id] == .attended }, exercises: exercises)
    }

    private func preferredLocalization(_ values: [ExerciseLocalizationRecord]) -> ExerciseLocalizationRecord? {
        let requested = Locale.current.language.languageCode?.identifier ?? "en"
        return values.first { $0.localeIdentifier == requested } ?? values.first { $0.localeIdentifier == "en" } ?? values.sorted { $0.localeIdentifier < $1.localeIdentifier }.first
    }

    private func packagePolicy(for booking: BookingRecord, status: SessionAttendanceStatus) -> SessionPackagePolicy {
        guard status == .attended, let package = booking.expectedPackage else { return .skip }
        let balance = package.initialUnits + (package.ledgerEntries ?? []).reduce(Decimal.zero) { $0 + $1.unitDelta }
        return balance > 0 ? .redeem : .insufficientBalance
    }

    private func bookings(sessionID: UUID) throws -> [BookingRecord] {
        try context.fetch(FetchDescriptor<BookingRecord>()).filter { $0.sessionID == sessionID }
    }
    private func completion(token: UUID) throws -> CompletedSessionRecord? {
        try context.fetch(FetchDescriptor<CompletedSessionRecord>()).first { $0.completionToken == token }
    }
    private func activeCompletion(sessionID: UUID) throws -> CompletedSessionRecord? {
        try context.fetch(FetchDescriptor<CompletedSessionRecord>()).first { $0.sessionID == sessionID && $0.isActiveRevision }
    }
    private func previousReportID(dogID: UUID, completion: CompletedSessionRecord?) throws -> UUID? {
        guard let completion else { return nil }
        return try context.fetch(FetchDescriptor<ClientReportRecord>()).first { $0.completedSessionID == completion.id && $0.dogID == dogID }?.id
    }
    private func result(for completed: CompletedSessionRecord) throws -> PersistentCompletionResult {
        let sessionBookings = try bookings(sessionID: completed.sessionID)
        let bookingIDs = Set(sessionBookings.map(\.id))
        let attendance = try context.fetch(FetchDescriptor<AttendanceRecord>()).filter { bookingIDs.contains($0.bookingID) && $0.completionRevision == completed.revision }
        let attendanceIDs = Set(attendance.map(\.id))
        return PersistentCompletionResult(
            completedSessionID: completed.id,
            sessionID: completed.sessionID,
            completionToken: completed.completionToken,
            revision: completed.revision,
            attendanceCount: attendance.count,
            resultCount: try context.fetch(FetchDescriptor<DogExerciseResultRecord>()).filter { attendanceIDs.contains($0.attendanceID) }.count,
            redemptionCount: try context.fetch(FetchDescriptor<PackageLedgerEntryRecord>()).filter { $0.kindRawValue == "redeem" && $0.attendanceID.map(attendanceIDs.contains) == true }.count,
            reportCount: try context.fetch(FetchDescriptor<ClientReportRecord>()).filter { $0.completedSessionID == completed.id }.count
        )
    }

    private static func fingerprint(_ request: PersistentCompletionRequest) -> String {
        let attendance = request.attendanceByBookingID.map { "\($0.key.uuidString):\($0.value.rawValue)" }.sorted().joined(separator: "|")
        let overrides = request.overrides.map { "\($0.bookingID.uuidString):\($0.exerciseVersionID.uuidString):\($0.outcome.rawValue)" }.sorted().joined(separator: "|")
        let value = "\(request.sessionID.uuidString)#\(request.defaultOutcome.rawValue)#\(attendance)#\(overrides)"
        return SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func correctionFingerprint(_ request: SessionCorrectionRequest, normalizedReason: String) -> String {
        let changes = request.changes.map { change in
            switch change {
            case .attendance(let bookingID, let status): "attendance:\(bookingID.uuidString):\(status.rawValue)"
            case .outcome(let bookingID, let exerciseVersionID, let outcome): "outcome:\(bookingID.uuidString):\(exerciseVersionID.uuidString):\(outcome.rawValue)"
            }
        }.sorted().joined(separator: "|")
        let value = "correction#\(request.originalCompletedSessionID.uuidString)#\(normalizedReason)#\(changes)"
        return SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
