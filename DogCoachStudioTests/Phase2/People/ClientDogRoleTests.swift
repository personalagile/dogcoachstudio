import Foundation
import SwiftData
import Testing
@testable import DogCoachStudio

@Suite("Phase 2 client-dog roles")
struct ClientDogRoleTests {
    @Test("The first role becomes primary and duplicate domain keys are rejected")
    @MainActor
    func primaryAndUniqueRoleInvariant() throws {
        let fixture = try RoleFixture()
        let client = try fixture.makeClient("Primary")
        let dog = try fixture.makeDog("Dog")

        let first = try fixture.useCases.assignRole(
            clientID: client.id,
            dogID: dog.id,
            kind: .owner,
            isPrimaryContact: false
        )
        #expect(first.isPrimaryContact)

        #expect(throws: PeopleDomainError.duplicateRole) {
            try fixture.useCases.assignRole(
                clientID: client.id,
                dogID: dog.id,
                kind: .owner,
                isPrimaryContact: false
            )
        }
        #expect(try fixture.repository.roles(clientID: nil, dogID: dog.id).count == 1)
    }

    @Test("Selecting another primary contact leaves exactly one primary")
    @MainActor
    func switchPrimaryContact() throws {
        let fixture = try RoleFixture()
        let firstClient = try fixture.makeClient("First")
        let secondClient = try fixture.makeClient("Second")
        let dog = try fixture.makeDog("Dog")
        let first = try fixture.useCases.assignRole(
            clientID: firstClient.id,
            dogID: dog.id,
            kind: .owner,
            isPrimaryContact: true
        )
        let second = try fixture.useCases.assignRole(
            clientID: secondClient.id,
            dogID: dog.id,
            kind: .handler,
            isPrimaryContact: false
        )

        try fixture.useCases.setPrimaryContact(roleID: second.id, dogID: dog.id)
        let roles = try fixture.repository.roles(clientID: nil, dogID: dog.id)

        #expect(roles.filter(\.isPrimaryContact).map(\.id) == [second.id])
        #expect(!roles.first(where: { $0.id == first.id })!.isPrimaryContact)
    }

    @Test("The primary role cannot be removed while another role would remain")
    @MainActor
    func primaryRemovalIsRejected() throws {
        let fixture = try RoleFixture()
        let firstClient = try fixture.makeClient("First")
        let secondClient = try fixture.makeClient("Second")
        let dog = try fixture.makeDog("Dog")
        let primary = try fixture.useCases.assignRole(
            clientID: firstClient.id,
            dogID: dog.id,
            kind: .owner,
            isPrimaryContact: true
        )
        _ = try fixture.useCases.assignRole(
            clientID: secondClient.id,
            dogID: dog.id,
            kind: .handler,
            isPrimaryContact: false
        )

        #expect(throws: PeopleDomainError.primaryContactRequired) {
            try fixture.useCases.removeRole(id: primary.id)
        }
        #expect(try fixture.repository.roles(clientID: nil, dogID: dog.id).count == 2)
    }

    @Test("Selecting an owner replaces the previous owner without exposing role setup")
    @MainActor
    func replaceOwner() throws {
        let fixture = try RoleFixture()
        let first = try fixture.makeClient("First owner")
        let second = try fixture.makeClient("Second owner")
        let dog = try fixture.makeDog("Dog")

        try fixture.useCases.setOwner(dogID: dog.id, clientID: first.id)
        try fixture.useCases.setOwner(dogID: dog.id, clientID: second.id)

        let roles = try fixture.repository.roles(clientID: nil, dogID: dog.id)
        #expect(roles.count == 1)
        #expect(roles.first?.clientID == second.id)
        #expect(roles.first?.roleRawValue == ClientDogRoleKind.owner.rawValue)
        #expect(roles.first?.isPrimaryContact == true)

        try fixture.useCases.setOwner(dogID: dog.id, clientID: nil)
        #expect(try fixture.repository.roles(clientID: nil, dogID: dog.id).isEmpty)
    }
}

@MainActor
private struct RoleFixture {
    let container: ModelContainer
    let repository: SwiftDataPeopleRepository
    let useCases: PeopleUseCases

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
        repository = SwiftDataPeopleRepository(context: container.mainContext)
        useCases = PeopleUseCases(
            repository: repository,
            clock: FixedAppClock(date: Date(timeIntervalSince1970: 1_750_000_000)),
            uuidGenerator: SystemUUIDGenerator()
        )
    }

    func makeClient(_ name: String) throws -> ClientRecord {
        try useCases.createClient(ClientDraft(
            displayName: name, email: nil, phone: nil, addressStreet: nil,
            addressPostalCode: nil, addressCity: nil, addressCountryCode: nil, privateNotes: nil
        ))
    }

    func makeDog(_ name: String) throws -> DogRecord {
        try useCases.createDog(DogDraft(
            name: name, photoAssetID: nil, birthDate: nil, breedText: nil,
            sexRawValue: nil, safetyFlagRawValues: [], safetyPrivateNote: nil
        ))
    }
}
