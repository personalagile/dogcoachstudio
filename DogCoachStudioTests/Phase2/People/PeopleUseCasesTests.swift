import Foundation
import SwiftData
import Testing
@testable import DogCoachStudio

@Suite("Phase 2 people management")
struct PeopleUseCasesTests {
    @Test("Clients can be created, searched case-insensitively, edited, and archived")
    @MainActor
    func clientLifecycle() throws {
        let fixture = try PeopleFixture()
        let client = try fixture.useCases.createClient(ClientDraft(
            displayName: "  Anna Example  ",
            email: " anna@example.test ",
            phone: nil,
            addressStreet: nil,
            addressPostalCode: nil,
            addressCity: nil,
            addressCountryCode: nil,
            privateNotes: " trainer only "
        ))

        #expect(client.displayName == "Anna Example")
        #expect(client.email == "anna@example.test")
        #expect(try fixture.useCases.searchClients("ANNA").map(\.id) == [client.id])

        let edited = try fixture.useCases.editClient(id: client.id, draft: ClientDraft(
            displayName: "Anna Updated",
            email: "",
            phone: "+49 123",
            addressStreet: nil,
            addressPostalCode: nil,
            addressCity: nil,
            addressCountryCode: nil,
            privateNotes: nil
        ))
        #expect(edited.displayName == "Anna Updated")
        #expect(edited.email == nil)
        #expect(edited.phone == "+49 123")

        _ = try fixture.useCases.setClientArchived(id: client.id, archived: true)
        #expect(try fixture.useCases.searchClients().isEmpty)
        #expect(try fixture.useCases.searchClients(includeArchived: true).map(\.id) == [client.id])
    }

    @Test("Archiving a dog preserves its intake, goals, and identity")
    @MainActor
    func archivePreservesHistory() throws {
        let fixture = try PeopleFixture()
        let dog = try fixture.useCases.createDog(.fixture(name: "History Dog"))
        let intake = IntakeRecordEntity(dogID: dog.id)
        intake.dog = dog
        let goal = TrainingGoalRecord(dogID: dog.id, title: "Stay calm")
        goal.dog = dog
        dog.intakeRecords = [intake]
        dog.trainingGoals = [goal]
        fixture.context.insert(intake)
        fixture.context.insert(goal)
        try fixture.context.save()

        _ = try fixture.useCases.setDogArchived(id: dog.id, archived: true)

        let persistedDog = try #require(try fixture.repository.dog(id: dog.id))
        #expect(persistedDog.isArchived)
        #expect(persistedDog.intakeRecords?.map(\.id) == [intake.id])
        #expect(persistedDog.trainingGoals?.map(\.id) == [goal.id])
        #expect(throws: PeopleDomainError.recordHasHistory) {
            try fixture.useCases.deleteDog(id: dog.id)
        }
        #expect(try fixture.repository.dog(id: dog.id) != nil)
    }

    @Test("Dog search ignores archived records unless requested")
    @MainActor
    func dogSearchAndArchiveFilter() throws {
        let fixture = try PeopleFixture()
        let active = try fixture.useCases.createDog(.fixture(name: "Luna Active"))
        let archived = try fixture.useCases.createDog(.fixture(name: "Luna Archived"))
        _ = try fixture.useCases.setDogArchived(id: archived.id, archived: true)

        #expect(try fixture.useCases.searchDogs(" luna ").map(\.id) == [active.id])
        #expect(Set(try fixture.useCases.searchDogs("LUNA", includeArchived: true).map(\.id)) == [active.id, archived.id])
    }

    @Test("Client detail resolves packages through linked dogs and derives balance from ledger")
    @MainActor
    func clientPackages() throws {
        let fixture = try PeopleFixture()
        let client = try fixture.useCases.createClient(.init(displayName: "Package Owner"))
        let dog = try fixture.useCases.createDog(.fixture(name: "Luna"))
        try fixture.useCases.assignRole(clientID: client.id, dogID: dog.id, kind: .owner, isPrimaryContact: true)
        let packageRepository = PackageLedgerRepository(context: fixture.context, uuid: SystemUUIDGenerator(), clock: fixture.clock)
        let packageID = try packageRepository.createPackage(.init(dogID: dog.id, name: "Ten sessions", unitType: .session, initialUnits: 10, purchasedAt: fixture.clock.now(), expiresAt: nil, paymentStatus: .paid, price: nil, currencyCode: nil))
        _ = try packageRepository.adjust(packageID: packageID, units: -2, reason: "Used before import")
        let model = PeopleFeatureModel(context: fixture.context, clock: fixture.clock, uuidGenerator: SystemUUIDGenerator())

        let package = try #require(model.packages(clientID: client.id).first)
        #expect(package.dogName == "Luna")
        #expect(package.name == "Ten sessions")
        #expect(package.balance == 8)
        #expect(package.status == .active)
    }
}

@MainActor
private struct PeopleFixture {
    let container: ModelContainer
    let context: ModelContext
    let repository: SwiftDataPeopleRepository
    let useCases: PeopleUseCases
    let clock = FixedAppClock(date: Date(timeIntervalSince1970: 1_750_000_000))

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
        context = container.mainContext
        repository = SwiftDataPeopleRepository(context: context)
        useCases = PeopleUseCases(
            repository: repository,
            clock: clock,
            uuidGenerator: SystemUUIDGenerator()
        )
    }
}

private extension DogDraft {
    static func fixture(name: String) -> DogDraft {
        DogDraft(
            name: name,
            photoAssetID: nil,
            birthDate: nil,
            breedText: nil,
            sexRawValue: nil,
            safetyFlagRawValues: [],
            safetyPrivateNote: nil
        )
    }
}
