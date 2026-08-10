import Foundation
import SwiftData
import Testing
@testable import DogCoachStudio

@Suite("Phase 1 schema v1 persistence")
struct SchemaV1PersistenceTests {
    @Test("In-memory store supports CRUD and optional relationships")
    @MainActor
    func inMemoryCRUDAndRelationships() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let client = ClientRecord(displayName: "Test Client")
        let dog = DogRecord(name: "Test Dog")
        let role = ClientDogRoleRecord(clientID: client.id, dogID: dog.id, isPrimaryContact: true)
        role.client = client
        role.dog = dog
        client.dogRoles = [role]
        dog.clientRoles = [role]

        context.insert(client)
        context.insert(dog)
        context.insert(role)
        try SchemaV1Validators.validate(role)
        try context.save()

        let clients = try context.fetch(FetchDescriptor<ClientRecord>())
        let dogs = try context.fetch(FetchDescriptor<DogRecord>())
        let roles = try context.fetch(FetchDescriptor<ClientDogRoleRecord>())
        #expect(clients.count == 1)
        #expect(dogs.count == 1)
        #expect(roles.count == 1)
        #expect(roles[0].client?.id == client.id)
        #expect(roles[0].dog?.id == dog.id)

        clients[0].displayName = "Updated Client"
        try context.save()
        #expect(try context.fetch(FetchDescriptor<ClientRecord>()).first?.displayName == "Updated Client")

        context.delete(role)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<ClientDogRoleRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ClientRecord>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<DogRecord>()).count == 1)
    }

    @Test("File-backed store survives a container restart")
    @MainActor
    func fileBackedRestart() throws {
        try TemporaryStore.withStoreURL { storeURL in
            let clientID = UUID()
            do {
                let container = try ModelContainerFactory.makeFileBacked(storeURL: storeURL)
                let client = ClientRecord(id: clientID, displayName: "Persistent Client")
                container.mainContext.insert(client)
                try container.mainContext.save()
            }

            do {
                let reopened = try ModelContainerFactory.makeFileBacked(storeURL: storeURL)
                let clients = try reopened.mainContext.fetch(FetchDescriptor<ClientRecord>())
                #expect(clients.count == 1)
                #expect(clients.first?.id == clientID)
                #expect(clients.first?.displayName == "Persistent Client")
            }
        }
    }

    @Test("Codable collection accessors survive a file-backed restart")
    @MainActor
    func codableCollectionRoundtrip() throws {
        try TemporaryStore.withStoreURL { storeURL in
            let dogID = UUID()
            let exerciseID = UUID()
            let versionID = UUID()
            let localizationID = UUID()
            let packID = UUID()
            let snapshotID = UUID()
            let categoryIDs = [UUID(), UUID()]
            let includedExerciseIDs = [exerciseID, UUID()]

            do {
                let container = try ModelContainerFactory.makeFileBacked(storeURL: storeURL)
                let context = container.mainContext

                let dog = DogRecord(id: dogID, name: "Collection Dog")
                dog.safetyFlagRawValues = ["needs-distance", "muzzle-trained"]

                let exercise = ExerciseRecord(id: exerciseID)
                exercise.categoryIDs = categoryIDs

                let version = ExerciseVersionRecord(id: versionID, exerciseID: exerciseID)
                version.equipment = ["mat", "long-line"]

                let localization = ExerciseLocalizationRecord(
                    id: localizationID,
                    exerciseVersionID: versionID,
                    localeIdentifier: "en"
                )
                localization.steps = ["Step one", "Step two"]
                localization.successCriteria = ["Calm", "Repeatable"]
                localization.commonErrors = ["Too close"]

                let pack = ContentPackRecord(id: packID, semanticVersion: "1.0.0", titleKey: "fixture")
                pack.includedExerciseIDs = includedExerciseIDs

                let snapshot = ExerciseSnapshotRecord(
                    id: snapshotID,
                    completedSessionID: UUID(),
                    sourceExerciseID: exerciseID,
                    sourceExerciseVersionID: versionID
                )
                snapshot.steps = ["Historical step"]
                snapshot.successCriteria = ["Historical criterion"]

                context.insert(dog)
                context.insert(exercise)
                context.insert(version)
                context.insert(localization)
                context.insert(pack)
                context.insert(snapshot)
                try context.save()
            }

            do {
                let reopened = try ModelContainerFactory.makeFileBacked(storeURL: storeURL)
                let context = reopened.mainContext
                let dog = try #require(context.fetch(FetchDescriptor<DogRecord>()).first { $0.id == dogID })
                let exercise = try #require(context.fetch(FetchDescriptor<ExerciseRecord>()).first { $0.id == exerciseID })
                let version = try #require(context.fetch(FetchDescriptor<ExerciseVersionRecord>()).first { $0.id == versionID })
                let localization = try #require(context.fetch(FetchDescriptor<ExerciseLocalizationRecord>()).first { $0.id == localizationID })
                let pack = try #require(context.fetch(FetchDescriptor<ContentPackRecord>()).first { $0.id == packID })
                let snapshot = try #require(context.fetch(FetchDescriptor<ExerciseSnapshotRecord>()).first { $0.id == snapshotID })

                #expect(dog.safetyFlagRawValues == ["needs-distance", "muzzle-trained"])
                #expect(exercise.categoryIDs == categoryIDs)
                #expect(version.equipment == ["mat", "long-line"])
                #expect(localization.steps == ["Step one", "Step two"])
                #expect(localization.successCriteria == ["Calm", "Repeatable"])
                #expect(localization.commonErrors == ["Too close"])
                #expect(pack.includedExerciseIDs == includedExerciseIDs)
                #expect(snapshot.steps == ["Historical step"])
                #expect(snapshot.successCriteria == ["Historical criterion"])
            }
        }
    }

    @Test("Schema v1 declares the complete model set")
    func schemaVersionAndModelsMatchGoldenFixture() throws {
        let fixtureURL = try #require(
            Bundle(for: SchemaFixtureBundleToken.self).url(forResource: "schema-v1", withExtension: "json")
        )
        let fixture = try JSONDecoder().decode(SchemaGoldenFixture.self, from: Data(contentsOf: fixtureURL))
        let modelNames = DogCoachSchemaV1.models.map { String(describing: $0) }

        #expect(fixture.version == "1.0.0")
        #expect(modelNames == fixture.models)
        #expect(DogCoachSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(DogCoachMigrationPlan.schemas.count == 1)
        #expect(DogCoachMigrationPlan.stages.isEmpty)
    }
}

private struct SchemaGoldenFixture: Decodable {
    let models: [String]
    let version: String
}

private final class SchemaFixtureBundleToken { }

private enum TemporaryStore {
    static func withStoreURL(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DogCoachStudioTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory.appendingPathComponent("SchemaV1.store"))
    }
}
