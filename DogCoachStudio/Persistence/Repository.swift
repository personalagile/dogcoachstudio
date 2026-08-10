import Foundation
import SwiftData

@MainActor
protocol Repository<Model> {
    associatedtype Model: PersistentModel

    func fetch(predicate: Predicate<Model>?, sortBy: [SortDescriptor<Model>]) throws -> [Model]
    func insert(_ model: Model) throws
    func delete(_ model: Model) throws
    func save() throws
}

@MainActor
final class SwiftDataRepository<Model: PersistentModel>: Repository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetch(
        predicate: Predicate<Model>? = nil,
        sortBy: [SortDescriptor<Model>] = []
    ) throws -> [Model] {
        do {
            return try context.fetch(FetchDescriptor(predicate: predicate, sortBy: sortBy))
        } catch {
            throw AppError.persistence(operation: "fetch")
        }
    }

    func insert(_ model: Model) throws {
        context.insert(model)
        try save()
    }

    func delete(_ model: Model) throws {
        context.delete(model)
        try save()
    }

    func save() throws {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            throw AppError.persistence(operation: "save")
        }
    }
}

