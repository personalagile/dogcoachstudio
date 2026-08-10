import Foundation
import SwiftData

@MainActor
final class SwiftDataPeopleRepository: PeopleRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func clients(search: String? = nil, includeArchived: Bool = false) throws -> [ClientRecord] {
        let records = try fetch(FetchDescriptor<ClientRecord>(sortBy: [SortDescriptor(\.displayName)]))
        return records.filter {
            (includeArchived || !$0.isArchived) && matches(search, value: $0.displayName)
        }
    }

    func client(id: UUID) throws -> ClientRecord? {
        try fetch(FetchDescriptor<ClientRecord>(predicate: #Predicate { $0.id == id })).first
    }

    func insert(_ client: ClientRecord) throws {
        context.insert(client)
        try saveChanges()
    }

    func save(_ client: ClientRecord) throws { try saveChanges() }

    func delete(_ client: ClientRecord) throws {
        context.delete(client)
        try saveChanges()
    }

    func dogs(search: String? = nil, includeArchived: Bool = false) throws -> [DogRecord] {
        let records = try fetch(FetchDescriptor<DogRecord>(sortBy: [SortDescriptor(\.name)]))
        return records.filter {
            (includeArchived || !$0.isArchived) && matches(search, value: $0.name)
        }
    }

    func dog(id: UUID) throws -> DogRecord? {
        try fetch(FetchDescriptor<DogRecord>(predicate: #Predicate { $0.id == id })).first
    }

    func insert(_ dog: DogRecord) throws {
        context.insert(dog)
        try saveChanges()
    }

    func save(_ dog: DogRecord) throws { try saveChanges() }

    func delete(_ dog: DogRecord) throws {
        context.delete(dog)
        try saveChanges()
    }

    func roles(clientID: UUID? = nil, dogID: UUID? = nil) throws -> [ClientDogRoleRecord] {
        let records = try fetch(FetchDescriptor<ClientDogRoleRecord>())
        return records.filter { role in
            (clientID == nil || role.clientID == clientID) && (dogID == nil || role.dogID == dogID)
        }
    }

    func insert(_ role: ClientDogRoleRecord) throws {
        context.insert(role)
        try saveChanges()
    }

    func save(_ role: ClientDogRoleRecord) throws { try saveChanges() }

    func delete(_ role: ClientDogRoleRecord) throws {
        context.delete(role)
        try saveChanges()
    }

    func saveChanges() throws {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            throw PeopleDomainError.persistence(operation: "save")
        }
    }

    private func fetch<Model: PersistentModel>(_ descriptor: FetchDescriptor<Model>) throws -> [Model] {
        do {
            return try context.fetch(descriptor)
        } catch {
            throw PeopleDomainError.persistence(operation: "fetch")
        }
    }

    private func matches(_ search: String?, value: String) -> Bool {
        guard let search = search?.trimmingCharacters(in: .whitespacesAndNewlines), !search.isEmpty else {
            return true
        }
        return value.localizedCaseInsensitiveContains(search)
    }
}
