import Foundation
import SwiftData

@MainActor
final class SwiftDataTrainingTemplateRepository {
    private let context: ModelContext
    private let uuid: any UUIDGenerating
    init(context: ModelContext, uuid: any UUIDGenerating) { self.context = context; self.uuid = uuid }

    func summaries(includeArchived: Bool = false) throws -> [TrainingTemplateSummary] {
        try context.fetch(FetchDescriptor<TrainingTemplateRecord>()).filter { includeArchived || !$0.isArchived }.compactMap { template in
            guard let version = (template.versions ?? []).first(where: { $0.id == template.currentVersionID }) else { return nil }
            let items = (version.exercises ?? []).sorted { $0.sortOrder < $1.sortOrder }
            return TrainingTemplateSummary(id: template.id, versionID: version.id, versionNumber: version.versionNumber, title: version.title, targetDurationMinutes: version.targetDurationMinutes, plannedDurationMinutes: items.compactMap(\.plannedDurationMinutes).reduce(0,+), exerciseCount: items.count, isPublished: version.publishedAt != nil, isArchived: template.isArchived)
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    func create(_ draft: TrainingTemplateDraft) throws -> UUID {
        try TemplateValidator.validate(draft)
        let template = TrainingTemplateRecord(id: uuid.makeUUID())
        let version = TemplateVersionRecord(id: uuid.makeUUID(), templateID: template.id, title: draft.title)
        context.insert(template); context.insert(version); template.currentVersionID = version.id; template.versions = [version]; version.template = template
        apply(draft, to: version); try context.save(); return template.id
    }

    func updateDraft(versionID: UUID, draft: TrainingTemplateDraft) throws {
        try TemplateValidator.validate(draft); let version = try requireVersion(versionID)
        guard version.publishedAt == nil else { throw TemplateError.publishedVersionImmutable }
        (version.exercises ?? []).forEach(context.delete); apply(draft, to: version); try context.save()
    }

    func publish(versionID: UUID, at date: Date) throws { let version = try requireVersion(versionID); if version.publishedAt == nil { version.publishedAt = date; try context.save() } }

    func createDraftVersion(templateID: UUID) throws -> UUID {
        guard let template = try context.fetch(FetchDescriptor<TrainingTemplateRecord>()).first(where: { $0.id == templateID }) else { throw TemplateError.templateNotFound }
        guard let source = (template.versions ?? []).first(where: { $0.id == template.currentVersionID }) else { throw TemplateError.versionNotFound }
        if source.publishedAt == nil { return source.id }
        let version = TemplateVersionRecord(id: uuid.makeUUID(), templateID: template.id, versionNumber: source.versionNumber + 1, title: source.title)
        version.targetDurationMinutes = source.targetDurationMinutes; version.audience = source.audience; version.trainerNotes = source.trainerNotes; version.supersedesVersionID = source.id; version.template = template
        version.exercises = (source.exercises ?? []).sorted { $0.sortOrder < $1.sortOrder }.enumerated().map { index, item in
            let clone = TemplateExerciseRecord(id: uuid.makeUUID(), templateVersionID: version.id, exerciseVersionID: item.exerciseVersionID, sortOrder: index)
            clone.plannedDurationMinutes = item.plannedDurationMinutes; clone.trainerInstruction = item.trainerInstruction; clone.templateVersion = version; context.insert(clone); return clone
        }
        context.insert(version); template.versions = (template.versions ?? []) + [version]; template.currentVersionID = version.id; try context.save(); return version.id
    }

    func setArchived(templateID: UUID, archived: Bool) throws { guard let template = try context.fetch(FetchDescriptor<TrainingTemplateRecord>()).first(where: { $0.id == templateID }) else { throw TemplateError.templateNotFound }; template.isArchived = archived; try context.save() }

    func editableDraft(templateID: UUID) throws -> (UUID, TrainingTemplateDraft) {
        let versionID = try createDraftVersion(templateID: templateID)
        let version = try requireVersion(versionID)
        let exercises = (version.exercises ?? []).sorted { $0.sortOrder < $1.sortOrder }.map {
            TemplateExerciseDraft(id: $0.id, exerciseVersionID: $0.exerciseVersionID, plannedDurationMinutes: $0.plannedDurationMinutes, trainerInstruction: $0.trainerInstruction)
        }
        return (versionID, TrainingTemplateDraft(title: version.title, targetDurationMinutes: version.targetDurationMinutes, audience: version.audience, trainerNotes: version.trainerNotes, exercises: exercises))
    }

    private func apply(_ draft: TrainingTemplateDraft, to version: TemplateVersionRecord) {
        version.title = draft.title; version.targetDurationMinutes = draft.targetDurationMinutes; version.audience = draft.audience; version.trainerNotes = draft.trainerNotes
        version.exercises = draft.exercises.enumerated().map { index, item in let record = TemplateExerciseRecord(id: item.id, templateVersionID: version.id, exerciseVersionID: item.exerciseVersionID, sortOrder: index); record.plannedDurationMinutes = item.plannedDurationMinutes; record.trainerInstruction = item.trainerInstruction; record.templateVersion = version; context.insert(record); return record }
    }
    private func requireVersion(_ id: UUID) throws -> TemplateVersionRecord { guard let value = try context.fetch(FetchDescriptor<TemplateVersionRecord>()).first(where: { $0.id == id }) else { throw TemplateError.versionNotFound }; return value }
}
