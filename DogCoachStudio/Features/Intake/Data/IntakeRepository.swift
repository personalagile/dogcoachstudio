import Foundation
import SwiftData

@MainActor
protocol IntakeRepository {
    func draft(id: UUID) throws -> IntakeDraft?
    func drafts(for dogID: UUID) throws -> [IntakeDraft]
    func save(_ draft: IntakeDraft) throws
    func deleteDraft(id: UUID) throws
}

@MainActor
final class SwiftDataIntakeRepository: IntakeRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func draft(id: UUID) throws -> IntakeDraft? {
        try fetchRecords().first(where: { $0.id == id }).map(Self.map)
    }

    func drafts(for dogID: UUID) throws -> [IntakeDraft] {
        try fetchRecords()
            .filter { $0.dogID == dogID }
            .map(Self.map)
    }

    func save(_ draft: IntakeDraft) throws {
        do {
            let dog = try dogRecord(id: draft.dogID)
            let record: IntakeRecordEntity
            if let existing = try fetchRecords().first(where: { $0.id == draft.id }) {
                record = existing
            } else {
                record = IntakeRecordEntity(
                    id: draft.id,
                    dogID: draft.dogID,
                    revision: draft.revision,
                    occurredAt: draft.occurredAt
                )
                context.insert(record)
            }

            record.dogID = draft.dogID
            record.dog = dog
            record.revision = draft.revision
            record.occurredAt = draft.occurredAt

            // Client-facing and trainer-private values are deliberately mapped separately.
            record.reason = draft.clientFacing.reason
            record.environment = draft.clientFacing.environment
            record.history = draft.clientFacing.history
            record.knownTriggers = draft.clientFacing.knownTriggers
            record.previousTraining = draft.clientFacing.previousTraining
            record.healthNotes = draft.clientFacing.healthNotes
            record.desiredOutcome = draft.clientFacing.desiredOutcome
            record.privateNotes = Self.nilIfEmpty(draft.privateFields.trainerNotes)

            try saveContext()
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.persistence(operation: "intake.save")
        }
    }

    func deleteDraft(id: UUID) throws {
        do {
            guard let record = try fetchRecords().first(where: { $0.id == id }) else { return }
            context.delete(record)
            try saveContext()
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.persistence(operation: "intake.delete")
        }
    }

    private func fetchRecords() throws -> [IntakeRecordEntity] {
        do {
            return try context.fetch(
                FetchDescriptor<IntakeRecordEntity>(
                    sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
                )
            )
        } catch {
            throw AppError.persistence(operation: "intake.fetch")
        }
    }

    private func dogRecord(id: UUID) throws -> DogRecord {
        do {
            guard let dog = try context.fetch(FetchDescriptor<DogRecord>()).first(where: { $0.id == id }) else {
                throw AppError.validation(code: "intake.dog-required")
            }
            return dog
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.persistence(operation: "intake.fetch-dog")
        }
    }

    private func saveContext() throws {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            throw AppError.persistence(operation: "intake.save")
        }
    }

    private static func map(_ record: IntakeRecordEntity) -> IntakeDraft {
        IntakeDraft(
            id: record.id,
            dogID: record.dogID,
            revision: record.revision,
            occurredAt: record.occurredAt,
            clientFacing: IntakeClientFacingFields(
                reason: record.reason,
                environment: record.environment,
                history: record.history,
                knownTriggers: record.knownTriggers,
                previousTraining: record.previousTraining,
                healthNotes: record.healthNotes,
                desiredOutcome: record.desiredOutcome
            ),
            privateFields: IntakePrivateFields(trainerNotes: record.privateNotes ?? "")
        )
    }

    private static func nilIfEmpty(_ value: String) -> String? {
        value.isEmpty ? nil : value
    }
}
