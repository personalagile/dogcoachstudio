import Foundation
import SwiftData
import Testing
@testable import DogCoachStudio

@Suite("Phase 6 data control")
struct DataControlTests {
    @Test("Backup roundtrip retains private fields, relationships, CSV, and manifest")
    @MainActor
    func backupRoundtrip() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let dog = DogRecord(name: "Pixel")
        dog.safetyFlagRawValues = ["distance"]
        dog.safetyPrivateNote = "PRIVATE-CANARY"
        let intake = IntakeRecordEntity(dogID: dog.id)
        intake.privateNotes = "INTAKE-CANARY"
        let package = TrainingPackageRecord(dogID: dog.id, name: "Ten visits", initialUnits: 10)
        context.insert(dog)
        context.insert(intake)
        context.insert(package)
        try context.save()

        let service = DataBackupService(context: context, now: { Date(timeIntervalSince1970: 1_700_000_000) })
        let encoded = try service.encodedPackage()
        let decoded = try DataBackupService.decodeAndValidate(encoded)

        #expect(decoded.manifest.recordCount == 3)
        #expect(decoded.manifest.backupSHA256.count == 64)
        #expect(decoded.backup.records.first { $0.entity == "Dog" }?.fields["safetyPrivateNote"] == "PRIVATE-CANARY")
        #expect(decoded.backup.records.first { $0.entity == "Intake" }?.fields["privateNotes"] == "INTAKE-CANARY")
        #expect(decoded.csvFiles.keys.contains("Dog"))
        let reencoded = try JSONEncoder.iso8601.encode(decoded)
        let roundtripped = try DataBackupService.decodeAndValidate(reencoded)
        #expect(decoded == roundtripped)
    }

    @Test("Damaged and unknown backup versions are rejected")
    @MainActor
    func invalidBackup() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let package = try DataBackupService(context: container.mainContext).exportPackage()
        let tampered = BackupPackage(manifest: package.manifest, backup: BackupDocument(schemaVersion: 1, exportedAt: package.backup.exportedAt, records: [BackupRecord(entity: "Dog", id: UUID(), fields: [:])]), csvFiles: package.csvFiles)
        #expect(throws: DataBackupError.checksumMismatch) { try DataBackupService.decodeAndValidate(try JSONEncoder.iso8601.encode(tampered)) }

        let unknown = BackupPackage(manifest: BackupManifest(format: "dogcoachstudio-backup", schemaVersion: 99, recordCount: 0, backupSHA256: ""), backup: BackupDocument(schemaVersion: 99, exportedAt: .now, records: []), csvFiles: [:])
        #expect(throws: DataBackupError.unknownVersion(99)) { try DataBackupService.decodeAndValidate(try JSONEncoder.iso8601.encode(unknown)) }
        #expect(throws: DataBackupError.damagedDocument) { try DataBackupService.decodeAndValidate(Data("broken".utf8)) }
    }

    @Test("Deletion preview requires export and preserves business history by default")
    @MainActor
    func deletionLifecycle() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let dog = DogRecord(name: "History")
        let package = TrainingPackageRecord(dogID: dog.id, name: "Package", initialUnits: 5)
        context.insert(dog)
        context.insert(package)
        try context.save()
        let service = DataLifecycleService(context: context)
        let preview = try service.previewDogDeletion(id: dog.id)
        #expect(preview.packages == 1)
        #expect(preview.exportRecommended)
        #expect(preview.containsBusinessHistory)
        #expect(throws: DataLifecycleError.exportConfirmationRequired) { try service.permanentlyDeleteDog(id: dog.id, exportConfirmed: false) }
        #expect(throws: DataLifecycleError.archiveRequiredForBusinessHistory) { try service.permanentlyDeleteDog(id: dog.id, exportConfirmed: true) }
        try service.archiveDog(id: dog.id)
        #expect(try context.fetch(FetchDescriptor<DogRecord>()).first?.isArchived == true)
    }

    @Test("Confirmed permanent deletion cascades without package orphans")
    @MainActor
    func deletionCascade() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let dog = DogRecord(name: "Delete")
        let package = TrainingPackageRecord(dogID: dog.id, name: "Package", initialUnits: 5)
        let ledger = PackageLedgerEntryRecord(packageID: package.id, kindRawValue: "purchase", unitDelta: 5)
        context.insert(dog); context.insert(package); context.insert(ledger)
        try context.save()
        try DataLifecycleService(context: context).permanentlyDeleteDog(id: dog.id, exportConfirmed: true, allowBusinessHistoryDeletion: true)
        #expect(try context.fetch(FetchDescriptor<DogRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<TrainingPackageRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PackageLedgerEntryRecord>()).isEmpty)
    }

    @Test("Realistic 200 dog and 10,000 result backup completes")
    @MainActor
    func largeDataset() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        for index in 0..<200 { context.insert(DogRecord(name: "Dog \(index)")) }
        let attendanceID = UUID(), snapshotID = UUID()
        for _ in 0..<10_000 { context.insert(DogExerciseResultRecord(attendanceID: attendanceID, exerciseSnapshotID: snapshotID)) }
        try context.save()
        let start = ContinuousClock.now
        let package = try DataBackupService(context: context).exportPackage()
        #expect(package.manifest.recordCount == 10_200)
        #expect(start.duration(to: .now) < .seconds(10))
    }
}

private extension JSONEncoder {
    static var iso8601: JSONEncoder {
        let value = JSONEncoder()
        value.dateEncodingStrategy = .iso8601
        value.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return value
    }
}
