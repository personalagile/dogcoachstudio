import Foundation
import SwiftData
import Testing
@testable import DogCoachStudio

@Suite("Phase 17 production bootstrap and restore")
struct ProductionBootstrapAndRestoreTests {
    @Test("Live environment seeds sample people only in Debug builds")
    @MainActor
    func liveBootstrapHasNoSeederCallContract() throws {
        let source = try String(contentsOf: projectFile("DogCoachStudio/App/AppEnvironment.swift"), encoding: .utf8)
        let liveBody = try #require(source.components(separatedBy: "static func preview()").first)
        let debugStart = try #require(liveBody.range(of: "#if DEBUG"))
        let debugEnd = try #require(liveBody.range(of: "#endif", range: debugStart.lowerBound..<liveBody.endIndex))
        #expect(liveBody[debugStart.lowerBound..<debugEnd.upperBound].contains("DemoDataSeeder.seedIfNeeded"))
        #expect(!liveBody[liveBody.startIndex..<debugStart.lowerBound].contains("DemoDataSeeder.seedIfNeeded"))
        #expect(!liveBody[debugEnd.upperBound..<liveBody.endIndex].contains("DemoDataSeeder.seedIfNeeded"))
    }

    @Test("Backup restores records, relationships, private fields, and media")
    @MainActor
    func completeRestore() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "dcs-restore-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceMedia = BackupMediaDirectories(
            dogPhotos: root.appending(path: "source-dogs", directoryHint: .isDirectory),
            exerciseMedia: root.appending(path: "source-exercises", directoryHint: .isDirectory)
        )
        try FileManager.default.createDirectory(at: sourceMedia.dogPhotos, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sourceMedia.exerciseMedia, withIntermediateDirectories: true)
        try Data("DOG-PHOTO".utf8).write(to: sourceMedia.dogPhotos.appending(path: "pixel.jpg"))
        try Data("EXERCISE-VIDEO".utf8).write(to: sourceMedia.exerciseMedia.appending(path: "video.mov"))
        try Data("[]".utf8).write(to: sourceMedia.exerciseMedia.appending(path: "manifest.json"))

        let source = try ModelContainerFactory.makeInMemory()
        let sourceContext = source.mainContext
        let ids = try seedCompleteGraph(context: sourceContext)
        let encoded = try DataBackupService(context: sourceContext, mediaDirectories: sourceMedia).encodedPackage()
        let package = try DataBackupService.decodeAndValidate(encoded)
        #expect(package.assets.count == 3)

        let destinationMedia = BackupMediaDirectories(
            dogPhotos: root.appending(path: "destination-dogs", directoryHint: .isDirectory),
            exerciseMedia: root.appending(path: "destination-exercises", directoryHint: .isDirectory)
        )
        let destination = try ModelContainerFactory.makeInMemory()
        let summary = try DataBackupRestoreService(context: destination.mainContext, mediaDirectories: destinationMedia).restore(package)

        #expect(summary.recordCount == 23)
        #expect(summary.assetCount == 3)
        let restoredDog = try #require(destination.mainContext.fetch(FetchDescriptor<DogRecord>()).first)
        #expect(restoredDog.id == ids.dog)
        #expect(restoredDog.safetyPrivateNote == "PRIVATE-DOG")
        #expect(restoredDog.clientRoles?.first?.client?.displayName == "Taylor")
        #expect(try destination.mainContext.fetch(FetchDescriptor<IntakeRecordEntity>()).first?.privateNotes == "PRIVATE-INTAKE")
        #expect(try destination.mainContext.fetch(FetchDescriptor<DogExerciseResultRecord>()).first?.trainerPrivateNote == "PRIVATE-RESULT")
        #expect(try destination.mainContext.fetch(FetchDescriptor<TrainingPackageRecord>()).first?.client?.displayName == "Taylor")
        #expect(try Data(contentsOf: destinationMedia.dogPhotos.appending(path: "pixel.jpg")) == Data("DOG-PHOTO".utf8))
        #expect(try Data(contentsOf: destinationMedia.exerciseMedia.appending(path: "video.mov")) == Data("EXERCISE-VIDEO".utf8))
    }

    @Test("Restore never merges into an existing workspace")
    @MainActor
    func existingStoreIsRejected() throws {
        let source = try ModelContainerFactory.makeInMemory()
        source.mainContext.insert(DogRecord(name: "Source"))
        try source.mainContext.save()
        let package = try DataBackupService(context: source.mainContext, mediaDirectories: nil).exportPackage()

        let destination = try ModelContainerFactory.makeInMemory()
        destination.mainContext.insert(DogRecord(name: "Existing"))
        try destination.mainContext.save()
        #expect(throws: DataRestoreError.storeNotEmpty) {
            try DataBackupRestoreService(context: destination.mainContext, mediaDirectories: nil).restore(package)
        }
        #expect(try destination.mainContext.fetch(FetchDescriptor<DogRecord>()).map(\.name) == ["Existing"])
    }

    @Test("Media traversal and tampering are rejected")
    @MainActor
    func assetIntegrity() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let document = BackupDocument(schemaVersion: 1, exportedAt: .now, records: [])
        let asset = BackupAsset(kind: .dogPhoto, relativePath: "../escape.jpg", data: Data("x".utf8), sha256: DataBackupService.hash(Data("x".utf8)))
        let manifest = BackupManifest(format: "dogcoachstudio-backup", schemaVersion: 1, recordCount: 0, backupSHA256: try checksumForEmptyBackup(document), assetCount: 1, assetsSHA256: DataBackupService.assetChecksum([asset]))
        let encoded = try JSONEncoder.iso8601Phase17.encode(BackupPackage(manifest: manifest, backup: document, csvFiles: [:], assets: [asset]))
        #expect(throws: DataBackupError.checksumMismatch) { try DataBackupService.decodeAndValidate(encoded) }
        #expect(try container.mainContext.fetch(FetchDescriptor<DogRecord>()).isEmpty)
    }

    @Test("Current production schema reopens a file-backed store")
    @MainActor
    func productionSchemaRestart() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "dcs-schema-baseline-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appending(path: "baseline.store")
        do {
            let first = try ModelContainerFactory.makeFileBacked(storeURL: url)
            first.mainContext.insert(ClientRecord(displayName: "Migration baseline"))
            try first.mainContext.save()
        }
        let reopened = try ModelContainerFactory.makeFileBacked(storeURL: url)
        #expect(try reopened.mainContext.fetch(FetchDescriptor<ClientRecord>()).first?.displayName == "Migration baseline")
    }

    @MainActor
    private func seedCompleteGraph(context: ModelContext) throws -> (dog: UUID, client: UUID) {
        let client = ClientRecord(displayName: "Taylor"); client.privateNotes = "PRIVATE-CLIENT"
        let dog = DogRecord(name: "Pixel"); dog.photoAssetID = "pixel.jpg"; dog.safetyPrivateNote = "PRIVATE-DOG"; dog.safetyFlagRawValues = ["distance"]
        let role = ClientDogRoleRecord(clientID: client.id, dogID: dog.id, isPrimaryContact: true); role.client = client; role.dog = dog
        let intake = IntakeRecordEntity(dogID: dog.id); intake.reason = "Leash"; intake.privateNotes = "PRIVATE-INTAKE"; intake.dog = dog
        let exercise = ExerciseRecord(); let version = ExerciseVersionRecord(exerciseID: exercise.id); version.exercise = exercise
        let localization = ExerciseLocalizationRecord(exerciseVersionID: version.id, localeIdentifier: "en"); localization.title = "Focus"; localization.exerciseVersion = version
        let goal = TrainingGoalRecord(dogID: dog.id, title: "Focus"); goal.dog = dog; goal.exerciseID = exercise.id; goal.exercise = exercise
        let template = TrainingTemplateRecord(); let templateVersion = TemplateVersionRecord(templateID: template.id, title: "Basics"); templateVersion.template = template
        let templateExercise = TemplateExerciseRecord(templateVersionID: templateVersion.id, exerciseVersionID: version.id, sortOrder: 0); templateExercise.templateVersion = templateVersion; templateExercise.exerciseVersion = version
        let pack = ContentPackRecord(semanticVersion: "1.0.0", titleKey: "foundation"); pack.author = "DogCoach"; pack.checksum = "checksum"
        exercise.contentPackID = pack.id; exercise.contentPack = pack; exercise.currentVersionID = version.id; pack.includedExerciseIDs = [exercise.id]
        let packageTemplate = PackageTemplateRecord(name: "Ten", units: 10, price: 120)
        let package = TrainingPackageRecord(dogID: dog.id, name: "Ten", initialUnits: 10); package.clientID = client.id; package.client = client; package.dog = dog; package.packageTemplateID = packageTemplate.id; package.packageTemplate = packageTemplate
        let session = ScheduledSessionRecord(title: "Class", startAt: .now, durationMinutes: 60); session.templateVersionID = templateVersion.id; session.templateVersion = templateVersion; session.labels = ["group"]
        let booking = BookingRecord(sessionID: session.id, dogID: dog.id); booking.session = session; booking.dog = dog; booking.expectedPackageID = package.id; booking.expectedPackage = package
        let attendance = AttendanceRecord(bookingID: booking.id, statusRawValue: "attended"); attendance.booking = booking
        let completion = CompletedSessionRecord(sessionID: session.id, completionToken: UUID()); completion.session = session; completion.requestFingerprint = "fingerprint"
        let snapshot = ExerciseSnapshotRecord(completedSessionID: completion.id, sourceExerciseID: exercise.id, sourceExerciseVersionID: version.id); snapshot.title = "Focus"; snapshot.completedSession = completion
        let result = DogExerciseResultRecord(attendanceID: attendance.id, exerciseSnapshotID: snapshot.id); result.attendance = attendance; result.exerciseSnapshot = snapshot; result.goalID = goal.id; result.goal = goal; result.trainerPrivateNote = "PRIVATE-RESULT"
        let report = ClientReportRecord(dogID: dog.id, completedSessionID: completion.id, localeIdentifier: "en"); report.dog = dog; report.completedSession = completion; report.body = "Client-safe"
        let ledger = PackageLedgerEntryRecord(packageID: package.id, kindRawValue: "purchase", unitDelta: 10); ledger.package = package; ledger.moneyDelta = 120; ledger.currencyCode = "EUR"
        let coupon = CouponRecord(code: "WELCOME", kindRawValue: "units", amount: 1); coupon.redeemedPackageID = package.id; coupon.redeemedPackage = package
        context.insert(client); context.insert(dog); context.insert(role); context.insert(intake); context.insert(exercise)
        context.insert(version); context.insert(localization); context.insert(goal); context.insert(template); context.insert(templateVersion)
        context.insert(templateExercise); context.insert(pack); context.insert(packageTemplate); context.insert(package); context.insert(session)
        context.insert(booking); context.insert(attendance); context.insert(completion); context.insert(snapshot); context.insert(result)
        context.insert(report); context.insert(ledger); context.insert(coupon)
        try context.save()
        return (dog.id, client.id)
    }

    private func projectFile(_ relativePath: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appending(path: relativePath)
    }

    @MainActor
    private func checksumForEmptyBackup(_ document: BackupDocument) throws -> String {
        let encoder = JSONEncoder.iso8601Phase17
        return DataBackupService.hash(try encoder.encode(document))
    }
}

private extension JSONEncoder {
    static var iso8601Phase17: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
