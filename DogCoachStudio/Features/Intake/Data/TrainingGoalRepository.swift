import Foundation
import SwiftData

@MainActor
protocol TrainingGoalRepository {
    func goals(for dogID: UUID) throws -> [TrainingGoal]
    func save(_ goal: TrainingGoal) throws
    func delete(id: UUID) throws
}

@MainActor
final class SwiftDataTrainingGoalRepository: TrainingGoalRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func goals(for dogID: UUID) throws -> [TrainingGoal] {
        try fetchRecords()
            .filter { $0.dogID == dogID }
            .map(Self.map)
    }

    func save(_ goal: TrainingGoal) throws {
        guard !goal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.validation(code: "training-goal.title-required")
        }

        do {
            let dog = try dogRecord(id: goal.dogID)
            let record: TrainingGoalRecord
            if let existing = try fetchRecords().first(where: { $0.id == goal.id }) {
                record = existing
            } else {
                record = TrainingGoalRecord(
                    id: goal.id,
                    dogID: goal.dogID,
                    title: goal.title,
                    startedAt: goal.startedAt
                )
                context.insert(record)
            }

            record.dogID = goal.dogID
            record.dog = dog
            record.title = goal.title
            record.statusRawValue = goal.status.rawValue
            record.targetDescription = goal.targetDescription
            record.startedAt = goal.startedAt
            record.completedAt = goal.completedAt
            record.exerciseID = goal.exerciseID
            try saveContext()
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.persistence(operation: "training-goal.save")
        }
    }

    func delete(id: UUID) throws {
        do {
            guard let record = try fetchRecords().first(where: { $0.id == id }) else { return }
            context.delete(record)
            try saveContext()
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.persistence(operation: "training-goal.delete")
        }
    }

    private func fetchRecords() throws -> [TrainingGoalRecord] {
        do {
            return try context.fetch(
                FetchDescriptor<TrainingGoalRecord>(
                    sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
                )
            )
        } catch {
            throw AppError.persistence(operation: "training-goal.fetch")
        }
    }

    private func dogRecord(id: UUID) throws -> DogRecord {
        do {
            guard let dog = try context.fetch(FetchDescriptor<DogRecord>()).first(where: { $0.id == id }) else {
                throw AppError.validation(code: "training-goal.dog-required")
            }
            return dog
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.persistence(operation: "training-goal.fetch-dog")
        }
    }

    private func saveContext() throws {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            throw AppError.persistence(operation: "training-goal.save")
        }
    }

    private static func map(_ record: TrainingGoalRecord) -> TrainingGoal {
        TrainingGoal(
            id: record.id,
            dogID: record.dogID,
            title: record.title,
            status: TrainingGoalStatus(rawValue: record.statusRawValue) ?? .planned,
            targetDescription: record.targetDescription,
            startedAt: record.startedAt,
            completedAt: record.completedAt,
            exerciseID: record.exerciseID
        )
    }
}
