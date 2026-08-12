import Foundation
import SwiftData
import Testing
@testable import DogCoachStudio

@Suite("Phase 4 scheduling and persistent completion")
struct SessionPhase4Tests {
    @Test("Session state machine rejects invalid transitions") @MainActor
    func stateMachine() throws {
        let fixture = try Phase4Fixture(dogCount: 1)
        #expect(!ScheduledSessionStatus.draft.canTransition(to: .completed))
        #expect(throws: SessionSchedulingError.invalidTransition(from: .inProgress, to: .scheduled)) {
            try fixture.sessions.transition(sessionID: fixture.sessionID, to: .scheduled)
        }
        #expect(try fixture.sessions.list().first?.status == .inProgress)
    }

    @Test("Booking has no package charge and overlapping sessions are flagged") @MainActor
    func bookingAndOverlap() throws {
        let fixture = try Phase4Fixture(dogCount: 2)
        _ = try fixture.sessions.create(.init(title: "Overlap", startAt: fixture.now.addingTimeInterval(600), durationMinutes: 45, locationText: nil, kind: .group, templateVersionID: nil, dogIDs: fixture.dogIDs))
        #expect(try fixture.context.fetchCount(FetchDescriptor<PackageLedgerEntryRecord>()) == 0)
        #expect(try fixture.sessions.list().filter(\.hasOverlap).count == 2)
    }

    @Test("Session overview exposes dog and primary owner names for search") @MainActor
    func participantSearchTerms() throws {
        let fixture = try Phase4Fixture(dogCount: 1)
        let dog = try #require(try fixture.context.fetch(FetchDescriptor<DogRecord>()).first)
        let client = ClientRecord(displayName: "Alex Owner", createdAt: fixture.now)
        let role = ClientDogRoleRecord(clientID: client.id, dogID: dog.id, isPrimaryContact: true)
        role.client = client; role.dog = dog; client.dogRoles = [role]; dog.clientRoles = [role]
        fixture.context.insert(client); fixture.context.insert(role); try fixture.context.save()

        let session = try #require(try fixture.sessions.list().first)
        #expect(session.participantNames == ["Dog 0 · Alex Owner"])
    }

    @Test("Preview scales from one to twenty dogs", arguments: [1, 5, 20]) @MainActor
    func previewScale(dogCount: Int) throws {
        let fixture = try Phase4Fixture(dogCount: dogCount)
        let request = try fixture.request()
        let preview = try fixture.completion.preview(request)
        #expect(preview.attendeeCount == dogCount)
        #expect(preview.resultCount == dogCount * 5)
        #expect(preview.reportCount == dogCount)
    }

    @Test("Insufficient balance warns but does not silently block completion") @MainActor
    func insufficientBalance() throws {
        let fixture = try Phase4Fixture(dogCount: 1, initialUnits: 0)
        let request = try fixture.request()
        #expect(try fixture.completion.preview(request).hasInsufficientBalance)
        #expect(try fixture.completion.complete(request).redemptionCount == 1)
    }

    @Test("Completion atomically materializes attendance, snapshots, results, reports and ledger") @MainActor
    func materialization() throws {
        let fixture = try Phase4Fixture(dogCount: 3)
        var request = try fixture.request()
        let absent = try #require(request.attendanceByBookingID.keys.sorted { $0.uuidString < $1.uuidString }.last)
        var attendance = request.attendanceByBookingID; attendance[absent] = .excused
        request = .init(sessionID: request.sessionID, completionToken: request.completionToken, attendanceByBookingID: attendance, defaultOutcome: request.defaultOutcome, overrides: [])
        let result = try fixture.completion.complete(request)
        #expect(result.attendanceCount == 3)
        #expect(result.resultCount == 10)
        #expect(result.reportCount == 2)
        #expect(result.redemptionCount == 2)
        #expect(try fixture.context.fetchCount(FetchDescriptor<ExerciseSnapshotRecord>()) == 5)
    }

    @Test("One thousand token replays create no duplicate") @MainActor
    func thousandReplays() throws {
        let fixture = try Phase4Fixture(dogCount: 2)
        let request = try fixture.request()
        let first = try fixture.completion.complete(request)
        for _ in 0..<1_000 { #expect(try fixture.completion.complete(request) == first) }
        #expect(try fixture.context.fetchCount(FetchDescriptor<CompletedSessionRecord>()) == 1)
        #expect(try fixture.context.fetchCount(FetchDescriptor<PackageLedgerEntryRecord>()) == 2)
    }

    @Test("Concurrent retries serialize to one completion") @MainActor
    func concurrentRetries() async throws {
        let fixture = try Phase4Fixture(dogCount: 2)
        let service = fixture.completion
        let request = try fixture.request()
        let results = try await withThrowingTaskGroup(of: PersistentCompletionResult.self) { group in
            for _ in 0..<20 { group.addTask { @MainActor in try service.complete(request) } }
            var values: [PersistentCompletionResult] = []
            for try await value in group { values.append(value) }
            return values
        }
        #expect(Set(results.map(\.completedSessionID)).count == 1)
        #expect(try fixture.context.fetchCount(FetchDescriptor<CompletedSessionRecord>()) == 1)
    }

    @Test("Failure injection rolls back every domain mutation") @MainActor
    func rollback() throws {
        let fixture = try Phase4Fixture(dogCount: 2)
        let before = try fixture.counts()
        fixture.completion.failurePoint = .beforeSave
        #expect(throws: PersistentCompletionError.injectedFailure) { try fixture.completion.complete(try fixture.request()) }
        #expect(try fixture.counts() == before)
        #expect(try fixture.sessions.list().first?.status == .inProgress)
    }

    @Test("Same token with changed payload is rejected") @MainActor
    func tokenConflict() throws {
        let fixture = try Phase4Fixture(dogCount: 1)
        let request = try fixture.request(); _ = try fixture.completion.complete(request)
        let changed = PersistentCompletionRequest(sessionID: request.sessionID, completionToken: request.completionToken, attendanceByBookingID: request.attendanceByBookingID, defaultOutcome: .strongSupport, overrides: [])
        #expect(throws: PersistentCompletionError.tokenPayloadConflict) { try fixture.completion.complete(changed) }
    }

    @Test("Correction preserves original and creates reversal, revision and report history") @MainActor
    func correction() throws {
        let fixture = try Phase4Fixture(dogCount: 1)
        let first = try fixture.completion.complete(try fixture.request())
        let correction = SessionCorrectionRequest(originalCompletedSessionID: first.completedSessionID, completionToken: UUID(), reason: "Attendance corrected", changes: [])
        let second = try fixture.completion.correct(correction)
        #expect(try fixture.completion.correct(correction) == second)
        #expect(second.revision == 2)
        let completions = try fixture.context.fetch(FetchDescriptor<CompletedSessionRecord>())
        #expect(completions.count == 2)
        #expect(completions.filter(\.isActiveRevision).count == 1)
        #expect(try fixture.context.fetch(FetchDescriptor<PackageLedgerEntryRecord>()).reduce(Decimal.zero) { $0 + $1.unitDelta } == -1)
        let reports = try fixture.context.fetch(FetchDescriptor<ClientReportRecord>())
        #expect(reports.count == 2)
        #expect(reports.contains { $0.revision == 2 && $0.supersedesReportID != nil })
        #expect(throws: PersistentCompletionError.tokenPayloadConflict) {
            try fixture.completion.correct(.init(originalCompletedSessionID: first.completedSessionID, completionToken: correction.completionToken, reason: "Different reason", changes: []))
        }
    }

    @Test("Correction requires an audit reason") @MainActor
    func correctionReason() throws {
        let fixture = try Phase4Fixture(dogCount: 1)
        let first = try fixture.completion.complete(try fixture.request())
        #expect(throws: PersistentCompletionError.correctionReasonRequired) {
            try fixture.completion.correct(.init(originalCompletedSessionID: first.completedSessionID, completionToken: UUID(), reason: "  ", changes: []))
        }
    }
}

@MainActor
private final class Phase4Fixture {
    let container: ModelContainer
    let context: ModelContext
    let sessions: SwiftDataScheduledSessionRepository
    let completion: SessionCompletionService
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    var sessionID: UUID = UUID()
    var dogIDs: [UUID] = []

    init(dogCount: Int, initialUnits: Decimal = 5) throws {
        container = try ModelContainerFactory.makeInMemory()
        context = container.mainContext
        let clock = FixedAppClock(date: now)
        sessions = .init(context: context, uuid: SystemUUIDGenerator())
        completion = .init(context: context, clock: clock, uuid: SystemUUIDGenerator())

        for index in 0..<dogCount {
            let dog = DogRecord(name: "Dog \(index)", createdAt: now); context.insert(dog); dogIDs.append(dog.id)
            let package = TrainingPackageRecord(dogID: dog.id, name: "Package", initialUnits: initialUnits, purchasedAt: now)
            package.dog = dog; context.insert(package)
        }
        let template = TrainingTemplateRecord(); let templateVersion = TemplateVersionRecord(templateID: template.id, title: "Five exercises")
        template.currentVersionID = templateVersion.id; template.versions = [templateVersion]; templateVersion.template = template; templateVersion.publishedAt = now
        context.insert(template); context.insert(templateVersion)
        templateVersion.exercises = (0..<5).map { index in
            let exercise = ExerciseRecord(); let version = ExerciseVersionRecord(exerciseID: exercise.id); let localization = ExerciseLocalizationRecord(exerciseVersionID: version.id, localeIdentifier: "en")
            localization.title = "Exercise \(index)"; localization.goal = "Goal"; localization.steps = ["Step"]; localization.successCriteria = ["Success"]
            exercise.currentVersionID = version.id; exercise.versions = [version]; version.exercise = exercise; version.localizations = [localization]; localization.exerciseVersion = version; version.publishedAt = now
            let item = TemplateExerciseRecord(templateVersionID: templateVersion.id, exerciseVersionID: version.id, sortOrder: index)
            item.templateVersion = templateVersion; item.exerciseVersion = version
            context.insert(exercise); context.insert(version); context.insert(localization); context.insert(item)
            return item
        }
        try context.save()
        sessionID = try sessions.create(.init(title: "Group", startAt: now, durationMinutes: 45, locationText: nil, kind: .group, templateVersionID: templateVersion.id, dogIDs: dogIDs))
        try sessions.transition(sessionID: sessionID, to: .scheduled)
        try sessions.transition(sessionID: sessionID, to: .inProgress)
    }

    func request() throws -> PersistentCompletionRequest {
        let session = try #require(try sessions.session(id: sessionID))
        return .init(sessionID: sessionID, completionToken: UUID(), attendanceByBookingID: Dictionary(uniqueKeysWithValues: (session.bookings ?? []).map { ($0.id, .attended) }), defaultOutcome: .independent, overrides: [])
    }

    func counts() throws -> [Int] {
        [
            try context.fetchCount(FetchDescriptor<CompletedSessionRecord>()),
            try context.fetchCount(FetchDescriptor<AttendanceRecord>()),
            try context.fetchCount(FetchDescriptor<ExerciseSnapshotRecord>()),
            try context.fetchCount(FetchDescriptor<DogExerciseResultRecord>()),
            try context.fetchCount(FetchDescriptor<PackageLedgerEntryRecord>()),
            try context.fetchCount(FetchDescriptor<ClientReportRecord>())
        ]
    }
}
