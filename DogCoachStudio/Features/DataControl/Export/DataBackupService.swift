import CryptoKit
import Foundation
import SwiftData

struct BackupRecord: Codable, Hashable, Sendable {
    let entity: String
    let id: UUID
    let fields: [String: String]
}

struct BackupDocument: Codable, Hashable, Sendable {
    static let currentVersion = 1
    let schemaVersion: Int
    let exportedAt: Date
    let records: [BackupRecord]
}

struct BackupManifest: Codable, Hashable, Sendable {
    let format: String
    let schemaVersion: Int
    let recordCount: Int
    let backupSHA256: String
}

struct BackupPackage: Codable, Hashable, Sendable {
    let manifest: BackupManifest
    let backup: BackupDocument
    let csvFiles: [String: String]
}

enum DataBackupError: Error, Equatable, Sendable {
    case unknownVersion(Int)
    case checksumMismatch
    case damagedDocument
}

@MainActor
struct DataBackupService {
    private let context: ModelContext
    private let now: @Sendable () -> Date

    init(context: ModelContext, now: @escaping @Sendable () -> Date = { .now }) {
        self.context = context
        self.now = now
    }

    func exportPackage() throws -> BackupPackage {
        let records = try allRecords().sorted { ($0.entity, $0.id.uuidString) < ($1.entity, $1.id.uuidString) }
        let backup = BackupDocument(schemaVersion: BackupDocument.currentVersion, exportedAt: now(), records: records)
        let checksum = try Self.checksum(for: backup)
        return BackupPackage(
            manifest: BackupManifest(
                format: "dogcoachstudio-backup",
                schemaVersion: backup.schemaVersion,
                recordCount: records.count,
                backupSHA256: checksum
            ),
            backup: backup,
            csvFiles: Self.makeCSVFiles(records: records)
        )
    }

    func encodedPackage() throws -> Data {
        try Self.encoder.encode(exportPackage())
    }

    static func decodeAndValidate(_ data: Data) throws -> BackupPackage {
        let package: BackupPackage
        do { package = try decoder.decode(BackupPackage.self, from: data) }
        catch { throw DataBackupError.damagedDocument }
        guard package.backup.schemaVersion == BackupDocument.currentVersion,
              package.manifest.schemaVersion == BackupDocument.currentVersion else {
            throw DataBackupError.unknownVersion(package.backup.schemaVersion)
        }
        guard package.manifest.format == "dogcoachstudio-backup",
              package.manifest.recordCount == package.backup.records.count,
              package.manifest.backupSHA256 == (try checksum(for: package.backup)) else {
            throw DataBackupError.checksumMismatch
        }
        return package
    }

    private func allRecords() throws -> [BackupRecord] {
        var output: [BackupRecord] = []
        output += try context.fetch(FetchDescriptor<ClientRecord>()).map { record("Client", $0.id, ["displayName": $0.displayName, "email": $0.email, "phone": $0.phone, "addressStreet": $0.addressStreet, "addressPostalCode": $0.addressPostalCode, "addressCity": $0.addressCity, "addressCountryCode": $0.addressCountryCode, "privateNotes": $0.privateNotes, "isArchived": text($0.isArchived), "createdAt": text($0.createdAt), "updatedAt": text($0.updatedAt)]) }
        output += try context.fetch(FetchDescriptor<ClientDogRoleRecord>()).map { record("ClientDogRole", $0.id, ["clientID": text($0.clientID), "dogID": text($0.dogID), "role": $0.roleRawValue, "isPrimaryContact": text($0.isPrimaryContact)]) }
        output += try context.fetch(FetchDescriptor<DogRecord>()).map { record("Dog", $0.id, ["name": $0.name, "photoAssetID": $0.photoAssetID, "birthDate": text($0.birthDate), "breedText": $0.breedText, "sex": $0.sexRawValue, "safetyFlags": json($0.safetyFlagRawValues), "safetyPrivateNote": $0.safetyPrivateNote, "isArchived": text($0.isArchived), "createdAt": text($0.createdAt), "updatedAt": text($0.updatedAt)]) }
        output += try context.fetch(FetchDescriptor<IntakeRecordEntity>()).map { record("Intake", $0.id, ["dogID": text($0.dogID), "revision": text($0.revision), "occurredAt": text($0.occurredAt), "reason": $0.reason, "environment": $0.environment, "history": $0.history, "knownTriggers": $0.knownTriggers, "previousTraining": $0.previousTraining, "healthNotes": $0.healthNotes, "desiredOutcome": $0.desiredOutcome, "privateNotes": $0.privateNotes]) }
        output += try context.fetch(FetchDescriptor<TrainingGoalRecord>()).map { record("TrainingGoal", $0.id, ["dogID": text($0.dogID), "title": $0.title, "status": $0.statusRawValue, "targetDescription": $0.targetDescription, "startedAt": text($0.startedAt), "completedAt": text($0.completedAt), "exerciseID": text($0.exerciseID)]) }
        output += try context.fetch(FetchDescriptor<ExerciseRecord>()).map { record("Exercise", $0.id, ["origin": $0.originRawValue, "contentPackID": text($0.contentPackID), "currentVersionID": text($0.currentVersionID), "categoryIDs": json($0.categoryIDs.map(\.uuidString)), "isArchived": text($0.isArchived)]) }
        output += try context.fetch(FetchDescriptor<ExerciseVersionRecord>()).map { record("ExerciseVersion", $0.id, ["exerciseID": text($0.exerciseID), "versionNumber": text($0.versionNumber), "durationMinutes": text($0.durationMinutes), "difficulty": $0.difficultyRawValue, "equipment": json($0.equipment), "safetyLevel": $0.safetyLevelRawValue, "publishedAt": text($0.publishedAt), "supersedesVersionID": text($0.supersedesVersionID)]) }
        output += try context.fetch(FetchDescriptor<ExerciseLocalizationRecord>()).map { record("ExerciseLocalization", $0.id, ["exerciseVersionID": text($0.exerciseVersionID), "localeIdentifier": $0.localeIdentifier, "title": $0.title, "goal": $0.goal, "setup": $0.setup, "steps": json($0.steps), "successCriteria": json($0.successCriteria), "commonErrors": json($0.commonErrors), "regression": $0.regression, "progression": $0.progression, "homework": $0.homework, "safetyNotes": $0.safetyNotes, "reviewStatus": $0.reviewStatusRawValue]) }
        output += try context.fetch(FetchDescriptor<TrainingTemplateRecord>()).map { record("TrainingTemplate", $0.id, ["currentVersionID": text($0.currentVersionID), "isArchived": text($0.isArchived)]) }
        output += try context.fetch(FetchDescriptor<TemplateVersionRecord>()).map { record("TemplateVersion", $0.id, ["templateID": text($0.templateID), "versionNumber": text($0.versionNumber), "title": $0.title, "targetDurationMinutes": text($0.targetDurationMinutes), "audience": $0.audience, "trainerNotes": $0.trainerNotes, "publishedAt": text($0.publishedAt), "supersedesVersionID": text($0.supersedesVersionID)]) }
        output += try context.fetch(FetchDescriptor<TemplateExerciseRecord>()).map { record("TemplateExercise", $0.id, ["templateVersionID": text($0.templateVersionID), "exerciseVersionID": text($0.exerciseVersionID), "sortOrder": text($0.sortOrder), "plannedDurationMinutes": text($0.plannedDurationMinutes), "trainerInstruction": $0.trainerInstruction]) }
        output += try context.fetch(FetchDescriptor<ContentPackRecord>()).map { record("ContentPack", $0.id, ["semanticVersion": $0.semanticVersion, "titleKey": $0.titleKey, "author": $0.author, "licenseMetadata": $0.licenseMetadata, "minimumAppVersion": $0.minimumAppVersion, "includedExerciseIDs": json($0.includedExerciseIDs.map(\.uuidString)), "entitlementID": $0.entitlementID, "checksum": $0.checksum]) }
        output += try context.fetch(FetchDescriptor<ScheduledSessionRecord>()).map { record("ScheduledSession", $0.id, ["title": $0.title, "startAt": text($0.startAt), "durationMinutes": text($0.durationMinutes), "locationText": $0.locationText, "kind": $0.kindRawValue, "status": $0.statusRawValue, "templateVersionID": text($0.templateVersionID), "calendarEventIdentifier": $0.calendarEventIdentifier, "labels": json($0.labels), "packageUnitsPerAttendee": text($0.packageUnitsPerAttendee)]) }
        output += try context.fetch(FetchDescriptor<BookingRecord>()).map { record("Booking", $0.id, ["sessionID": text($0.sessionID), "dogID": text($0.dogID), "bookingStatus": $0.bookingStatusRawValue, "expectedPackageID": text($0.expectedPackageID)]) }
        output += try context.fetch(FetchDescriptor<AttendanceRecord>()).map { record("Attendance", $0.id, ["bookingID": text($0.bookingID), "status": $0.statusRawValue, "checkedAt": text($0.checkedAt), "packagePolicy": $0.packagePolicyRawValue, "completionRevision": text($0.completionRevision), "isActiveRevision": text($0.isActiveRevision)]) }
        output += try context.fetch(FetchDescriptor<CompletedSessionRecord>()).map { record("CompletedSession", $0.id, ["sessionID": text($0.sessionID), "completedAt": text($0.completedAt), "completionToken": text($0.completionToken), "revision": text($0.revision), "requestFingerprint": $0.requestFingerprint, "supersedesCompletedSessionID": text($0.supersedesCompletedSessionID), "correctionReason": $0.correctionReason, "isActiveRevision": text($0.isActiveRevision), "generalNotes": $0.generalNotes, "defaultOutcome": $0.defaultOutcomeRawValue]) }
        output += try context.fetch(FetchDescriptor<ExerciseSnapshotRecord>()).map { record("ExerciseSnapshot", $0.id, ["completedSessionID": text($0.completedSessionID), "sourceExerciseID": text($0.sourceExerciseID), "sourceExerciseVersionID": text($0.sourceExerciseVersionID), "localeIdentifier": $0.localeIdentifier, "title": $0.title, "goal": $0.goal, "setup": $0.setup, "steps": json($0.steps), "successCriteria": json($0.successCriteria), "homework": $0.homework, "safetyNotes": $0.safetyNotes]) }
        output += try context.fetch(FetchDescriptor<DogExerciseResultRecord>()).map { record("DogExerciseResult", $0.id, ["attendanceID": text($0.attendanceID), "exerciseSnapshotID": text($0.exerciseSnapshotID), "goalID": text($0.goalID), "outcome": $0.outcomeRawValue, "wasPerformed": text($0.wasPerformed), "trainerPrivateNote": $0.trainerPrivateNote, "clientFacingNote": $0.clientFacingNote]) }
        output += try context.fetch(FetchDescriptor<ClientReportRecord>()).map { record("ClientReport", $0.id, ["dogID": text($0.dogID), "completedSessionID": text($0.completedSessionID), "localeIdentifier": $0.localeIdentifier, "status": $0.statusRawValue, "revision": text($0.revision), "supersedesReportID": text($0.supersedesReportID), "body": $0.body, "generatedAt": text($0.generatedAt), "approvedAt": text($0.approvedAt), "exportedAt": text($0.exportedAt)]) }
        output += try context.fetch(FetchDescriptor<TrainingPackageRecord>()).map { record("TrainingPackage", $0.id, ["dogID": text($0.dogID), "clientID": text($0.clientID), "packageTemplateID": text($0.packageTemplateID), "name": $0.name, "unitType": $0.unitTypeRawValue, "initialUnits": text($0.initialUnits), "purchasedAt": text($0.purchasedAt), "expiresAt": text($0.expiresAt), "paymentStatus": $0.paymentStatusRawValue, "priceSnapshot": text($0.priceSnapshot), "currencyCode": $0.currencyCode, "isClosed": text($0.isClosed)]) }
        output += try context.fetch(FetchDescriptor<PackageTemplateRecord>()).map { record("PackageTemplate", $0.id, ["name": $0.name, "unitType": $0.unitTypeRawValue, "units": text($0.units), "price": text($0.price), "currencyCode": $0.currencyCode, "isArchived": text($0.isArchived), "createdAt": text($0.createdAt)]) }
        output += try context.fetch(FetchDescriptor<PackageLedgerEntryRecord>()).map { record("PackageLedgerEntry", $0.id, ["packageID": text($0.packageID), "kind": $0.kindRawValue, "unitDelta": text($0.unitDelta), "moneyDelta": text($0.moneyDelta), "currencyCode": $0.currencyCode, "attendanceID": text($0.attendanceID), "reversesEntryID": text($0.reversesEntryID), "reason": $0.reason, "createdAt": text($0.createdAt)]) }
        output += try context.fetch(FetchDescriptor<CouponRecord>()).map { record("Coupon", $0.id, ["code": $0.code, "kind": $0.kindRawValue, "amount": text($0.amount), "currencyCode": $0.currencyCode, "issuedAt": text($0.issuedAt), "expiresAt": text($0.expiresAt), "redeemedAt": text($0.redeemedAt), "redeemedPackageID": text($0.redeemedPackageID)]) }
        return output
    }

    private func record(_ entity: String, _ id: UUID, _ fields: [String: String?]) -> BackupRecord {
        BackupRecord(entity: entity, id: id, fields: fields.compactMapValues { $0 })
    }

    private func text<T>(_ value: T?) -> String? { value.map(String.init(describing:)) }
    private func text<T>(_ value: T) -> String { String(describing: value) }
    private func json(_ strings: [String]) -> String {
        let data = (try? JSONEncoder().encode(strings)) ?? Data("[]".utf8)
        return String(decoding: data, as: UTF8.self)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static func checksum(for backup: BackupDocument) throws -> String {
        SHA256.hash(data: try encoder.encode(backup)).map { String(format: "%02x", $0) }.joined()
    }

    private static func makeCSVFiles(records: [BackupRecord]) -> [String: String] {
        Dictionary(grouping: records, by: \.entity).mapValues { rows in
            "id,payload\n" + rows.map { "\($0.id.uuidString),\(csv(Self.jsonString($0.fields)))" }.joined(separator: "\n")
        }
    }

    private static func jsonString(_ fields: [String: String]) -> String {
        String(decoding: (try? encoder.encode(fields)) ?? Data("{}".utf8), as: UTF8.self)
    }

    private static func csv(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
}

struct ProtectedFileWriter: Sendable {
    func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUnlessOpen], ofItemAtPath: url.path)
    }
}
