import Foundation
import SwiftData

@MainActor
enum DemoDataSeeder {
    static func seedIfNeeded(
        context: ModelContext,
        clock: any AppClock,
        uuidGenerator: any UUIDGenerating
    ) throws {
        var descriptor = FetchDescriptor<ClientRecord>()
        descriptor.fetchLimit = 1
        guard try context.fetch(descriptor).isEmpty else { return }

        let createdAt = clock.now()
        let client = ClientRecord(
            id: uuidGenerator.makeUUID(),
            displayName: String(localized: "Demo client", comment: "Name of the fictional Phase 1 demo client"),
            createdAt: createdAt
        )
        let dog = DogRecord(
            id: uuidGenerator.makeUUID(),
            name: String(localized: "Demo dog", comment: "Name of the fictional Phase 1 demo dog"),
            createdAt: createdAt
        )
        let role = ClientDogRoleRecord(
            id: uuidGenerator.makeUUID(),
            clientID: client.id,
            dogID: dog.id,
            isPrimaryContact: true
        )
        role.client = client
        role.dog = dog
        client.dogRoles = [role]
        dog.clientRoles = [role]

        try SchemaV1Validators.validate(role)
        context.insert(client)
        context.insert(dog)
        context.insert(role)
        try context.save()
    }
}

