import SwiftData

enum DogCoachSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        DogCoachSchemaV1.models + [PackageTemplateRecord.self]
    }
}
