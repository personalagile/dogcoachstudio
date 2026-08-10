import Foundation

@MainActor
final class PeopleUseCases {
    private let repository: any PeopleRepository
    private let clock: any AppClock
    private let uuidGenerator: any UUIDGenerating

    init(
        repository: any PeopleRepository,
        clock: any AppClock,
        uuidGenerator: any UUIDGenerating
    ) {
        self.repository = repository
        self.clock = clock
        self.uuidGenerator = uuidGenerator
    }

    func searchClients(_ query: String? = nil, includeArchived: Bool = false) throws -> [ClientRecord] {
        try repository.clients(search: query, includeArchived: includeArchived)
    }

    func createClient(_ draft: ClientDraft) throws -> ClientRecord {
        let now = clock.now()
        let client = ClientRecord(
            id: uuidGenerator.makeUUID(),
            displayName: try PeopleDomainValidator.validatedName(draft.displayName),
            createdAt: now
        )
        apply(draft, to: client)
        try repository.insert(client)
        return client
    }

    func editClient(id: UUID, draft: ClientDraft) throws -> ClientRecord {
        guard let client = try repository.client(id: id) else { throw PeopleDomainError.clientNotFound(id) }
        _ = try PeopleDomainValidator.validatedName(draft.displayName)
        apply(draft, to: client)
        client.updatedAt = clock.now()
        try repository.save(client)
        return client
    }

    func setClientArchived(id: UUID, archived: Bool) throws -> ClientRecord {
        guard let client = try repository.client(id: id) else { throw PeopleDomainError.clientNotFound(id) }
        client.isArchived = archived
        client.updatedAt = clock.now()
        try repository.save(client)
        return client
    }

    func deleteClient(id: UUID) throws {
        guard let client = try repository.client(id: id) else { throw PeopleDomainError.clientNotFound(id) }
        guard try repository.roles(clientID: id, dogID: nil).isEmpty else {
            throw PeopleDomainError.recordHasHistory
        }
        try repository.delete(client)
    }

    func searchDogs(_ query: String? = nil, includeArchived: Bool = false) throws -> [DogRecord] {
        try repository.dogs(search: query, includeArchived: includeArchived)
    }

    func createDog(_ draft: DogDraft) throws -> DogRecord {
        let now = clock.now()
        let dog = DogRecord(
            id: uuidGenerator.makeUUID(),
            name: try PeopleDomainValidator.validatedName(draft.name),
            createdAt: now
        )
        apply(draft, to: dog)
        try repository.insert(dog)
        return dog
    }

    func editDog(id: UUID, draft: DogDraft) throws -> DogRecord {
        guard let dog = try repository.dog(id: id) else { throw PeopleDomainError.dogNotFound(id) }
        _ = try PeopleDomainValidator.validatedName(draft.name)
        apply(draft, to: dog)
        dog.updatedAt = clock.now()
        try repository.save(dog)
        return dog
    }

    func setDogArchived(id: UUID, archived: Bool) throws -> DogRecord {
        guard let dog = try repository.dog(id: id) else { throw PeopleDomainError.dogNotFound(id) }
        dog.isArchived = archived
        dog.updatedAt = clock.now()
        try repository.save(dog)
        return dog
    }

    func deleteDog(id: UUID) throws {
        guard let dog = try repository.dog(id: id) else { throw PeopleDomainError.dogNotFound(id) }
        let assignedRoles = try repository.roles(clientID: nil, dogID: id)
        let hasHistory = !(dog.intakeRecords ?? []).isEmpty
            || !(dog.trainingGoals ?? []).isEmpty
            || !(dog.bookings ?? []).isEmpty
            || !(dog.packages ?? []).isEmpty
            || !(dog.reports ?? []).isEmpty
            || !assignedRoles.isEmpty
        guard !hasHistory else { throw PeopleDomainError.recordHasHistory }
        try repository.delete(dog)
    }

    @discardableResult
    func assignRole(
        clientID: UUID,
        dogID: UUID,
        kind: ClientDogRoleKind,
        isPrimaryContact: Bool
    ) throws -> ClientDogRoleRecord {
        guard let client = try repository.client(id: clientID) else { throw PeopleDomainError.clientNotFound(clientID) }
        guard let dog = try repository.dog(id: dogID) else { throw PeopleDomainError.dogNotFound(dogID) }
        let existing = try repository.roles(clientID: nil, dogID: dogID)
        try PeopleDomainValidator.validateUniqueRole(
            clientID: clientID,
            dogID: dogID,
            kind: kind,
            existingRoles: existing
        )

        let shouldBePrimary = isPrimaryContact || !existing.contains(where: \.isPrimaryContact)
        if shouldBePrimary {
            for role in existing where role.isPrimaryContact {
                role.isPrimaryContact = false
            }
        }

        let role = ClientDogRoleRecord(
            id: uuidGenerator.makeUUID(),
            clientID: clientID,
            dogID: dogID,
            roleRawValue: kind.rawValue,
            isPrimaryContact: shouldBePrimary
        )
        role.client = client
        role.dog = dog
        client.dogRoles = (client.dogRoles ?? []) + [role]
        dog.clientRoles = (dog.clientRoles ?? []) + [role]
        try repository.insert(role)
        return role
    }

    func setPrimaryContact(roleID: UUID, dogID: UUID) throws {
        let roles = try repository.roles(clientID: nil, dogID: dogID)
        guard let selected = roles.first(where: { $0.id == roleID }) else {
            throw PeopleDomainError.roleNotFound(roleID)
        }
        for role in roles { role.isPrimaryContact = role.id == selected.id }
        try repository.saveChanges()
    }

    func removeRole(id: UUID) throws {
        let allRoles = try repository.roles(clientID: nil, dogID: nil)
        guard let role = allRoles.first(where: { $0.id == id }) else { throw PeopleDomainError.roleNotFound(id) }
        let dogRoles = allRoles.filter { $0.dogID == role.dogID }
        if role.isPrimaryContact && dogRoles.count > 1 {
            throw PeopleDomainError.primaryContactRequired
        }
        role.client?.dogRoles?.removeAll { $0.id == role.id }
        role.dog?.clientRoles?.removeAll { $0.id == role.id }
        try repository.delete(role)
    }

    private func apply(_ draft: ClientDraft, to client: ClientRecord) {
        client.displayName = draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        client.email = normalized(draft.email)
        client.phone = normalized(draft.phone)
        client.addressStreet = normalized(draft.addressStreet)
        client.addressPostalCode = normalized(draft.addressPostalCode)
        client.addressCity = normalized(draft.addressCity)
        client.addressCountryCode = normalized(draft.addressCountryCode)
        client.privateNotes = normalized(draft.privateNotes)
    }

    private func apply(_ draft: DogDraft, to dog: DogRecord) {
        dog.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        dog.photoAssetID = normalized(draft.photoAssetID)
        dog.birthDate = draft.birthDate
        dog.breedText = normalized(draft.breedText)
        dog.sexRawValue = normalized(draft.sexRawValue)
        dog.safetyFlagRawValues = Array(Set(draft.safetyFlagRawValues)).sorted()
        dog.safetyPrivateNote = normalized(draft.safetyPrivateNote)
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
