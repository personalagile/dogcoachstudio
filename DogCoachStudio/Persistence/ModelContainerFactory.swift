import Foundation
import SwiftData

enum ModelContainerFactory {
    static func makeDefault(fileManager: FileManager = .default) throws -> ModelContainer {
        let root = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root.appending(path: "DogCoachStudio", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return try makeFileBacked(storeURL: directory.appending(path: "DogCoachStudio.store"))
    }

    static func makeInMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "DogCoachStudio-InMemory",
            schema: Schema(versionedSchema: DogCoachSchemaV1.self),
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try makeContainer(configuration: configuration)
    }

    static func makeFileBacked(storeURL: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "DogCoachStudio-Local",
            schema: Schema(versionedSchema: DogCoachSchemaV1.self),
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try makeContainer(configuration: configuration)
    }

    private static func makeContainer(configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: DogCoachSchemaV1.self),
            migrationPlan: DogCoachMigrationPlan.self,
            configurations: configuration
        )
    }
}
