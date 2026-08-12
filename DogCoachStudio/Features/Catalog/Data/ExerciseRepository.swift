import Foundation
import SwiftData

@MainActor
protocol ExerciseRepository {
    func create(_ draft: ExerciseDraft) throws -> UUID
    func createDraftVersion(exerciseID: UUID) throws -> UUID
    func updateDraft(versionID: UUID, draft: ExerciseDraft) throws
    func publish(versionID: UUID, at date: Date) throws
    func search(_ query: String, locale: String, includeArchived: Bool) throws -> [ExerciseSummary]
    func setArchived(exerciseID: UUID, archived: Bool) throws
    func editableDraft(exerciseID: UUID) throws -> (UUID, ExerciseDraft)
}

@MainActor
final class SwiftDataExerciseRepository: ExerciseRepository {
    private let context: ModelContext
    private let uuid: any UUIDGenerating
    init(context: ModelContext, uuid: any UUIDGenerating) { self.context = context; self.uuid = uuid }

    func create(_ draft: ExerciseDraft) throws -> UUID {
        try CatalogValidator.validate(draft)
        let exercise = ExerciseRecord(id: uuid.makeUUID())
        let version = ExerciseVersionRecord(id: uuid.makeUUID(), exerciseID: exercise.id)
        context.insert(exercise); context.insert(version)
        exercise.versions = [version]; exercise.currentVersionID = version.id; version.exercise = exercise
        try apply(draft, to: version, exercise: exercise); try save(); return exercise.id
    }

    func createDraftVersion(exerciseID: UUID) throws -> UUID {
        let exercise = try requireExercise(exerciseID)
        guard let source = currentVersion(exercise) else { throw CatalogError.versionNotFound }
        if source.publishedAt == nil { return source.id }
        let version = ExerciseVersionRecord(id: uuid.makeUUID(), exerciseID: exercise.id, versionNumber: source.versionNumber + 1)
        version.durationMinutes = source.durationMinutes; version.difficultyRawValue = source.difficultyRawValue
        version.equipment = source.equipment; version.safetyLevelRawValue = source.safetyLevelRawValue
        version.supersedesVersionID = source.id; version.exercise = exercise
        version.localizations = (source.localizations ?? []).map { clone($0, versionID: version.id) }
        context.insert(version); version.localizations?.forEach(context.insert)
        exercise.versions = (exercise.versions ?? []) + [version]; exercise.currentVersionID = version.id
        try save(); return version.id
    }

    func updateDraft(versionID: UUID, draft: ExerciseDraft) throws {
        try CatalogValidator.validate(draft)
        let version = try requireVersion(versionID)
        guard version.publishedAt == nil else { throw CatalogError.publishedVersionImmutable }
        guard let exercise = version.exercise ?? (try? requireExercise(version.exerciseID)) else { throw CatalogError.exerciseNotFound }
        (version.localizations ?? []).forEach(context.delete)
        try apply(draft, to: version, exercise: exercise); try save()
    }

    func publish(versionID: UUID, at date: Date) throws {
        let version = try requireVersion(versionID)
        guard version.publishedAt == nil else { return }
        guard !(version.localizations ?? []).isEmpty else { throw CatalogError.localizationRequired }
        version.publishedAt = date; try save()
    }

    func search(_ query: String, locale: String, includeArchived: Bool) throws -> [ExerciseSummary] {
        let needle = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return try context.fetch(FetchDescriptor<ExerciseRecord>()).filter { includeArchived || !$0.isArchived }.compactMap { exercise in
            guard let version = currentVersion(exercise), let resolved = ExerciseLocaleResolver.resolve((version.localizations ?? []).map(Self.localization), requestedLocale: locale) else { return nil }
            let haystack = ([resolved.content.title, resolved.content.goal] + version.equipment).joined(separator: " ").folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard needle.isEmpty || haystack.contains(needle) else { return nil }
            return ExerciseSummary(id: exercise.id, versionID: version.id, versionNumber: version.versionNumber, title: resolved.content.title, goal: resolved.content.goal, durationMinutes: version.durationMinutes, equipment: version.equipment, isPublished: version.publishedAt != nil, isArchived: exercise.isArchived, localeResolution: resolved)
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    func setArchived(exerciseID: UUID, archived: Bool) throws { try requireExercise(exerciseID).isArchived = archived; try save() }

    func editableDraft(exerciseID: UUID) throws -> (UUID, ExerciseDraft) {
        let exercise = try requireExercise(exerciseID)
        let versionID = try createDraftVersion(exerciseID: exerciseID)
        let version = try requireVersion(versionID)
        return (versionID, ExerciseDraft(
            durationMinutes: version.durationMinutes,
            difficulty: ExerciseDifficulty(rawValue: version.difficultyRawValue) ?? .foundation,
            equipment: version.equipment,
            safetyLevel: ExerciseSafetyLevel(rawValue: version.safetyLevelRawValue) ?? .standard,
            categoryIDs: exercise.categoryIDs,
            localizations: (version.localizations ?? []).map(Self.localization)
        ))
    }

    private func apply(_ draft: ExerciseDraft, to version: ExerciseVersionRecord, exercise: ExerciseRecord) throws {
        exercise.categoryIDs = draft.categoryIDs; version.durationMinutes = draft.durationMinutes
        version.difficultyRawValue = draft.difficulty.rawValue; version.equipment = draft.equipment; version.safetyLevelRawValue = draft.safetyLevel.rawValue
        version.localizations = draft.localizations.map { item in
            let record = ExerciseLocalizationRecord(id: uuid.makeUUID(), exerciseVersionID: version.id, localeIdentifier: item.localeIdentifier)
            record.title = item.title; record.goal = item.goal; record.setup = item.setup; record.steps = item.steps
            record.successCriteria = item.successCriteria
            record.commonErrors = ExerciseSupplementCodec.encode(problems: item.commonErrors, measures: item.correctiveMeasures)
            record.regression = item.regression
            record.progression = item.progression; record.homework = item.homework; record.safetyNotes = item.safetyNotes
            record.reviewStatusRawValue = item.reviewStatus.rawValue; record.exerciseVersion = version; context.insert(record); return record
        }
    }
    private func requireExercise(_ id: UUID) throws -> ExerciseRecord { guard let value = try context.fetch(FetchDescriptor<ExerciseRecord>()).first(where: { $0.id == id }) else { throw CatalogError.exerciseNotFound }; return value }
    private func requireVersion(_ id: UUID) throws -> ExerciseVersionRecord { guard let value = try context.fetch(FetchDescriptor<ExerciseVersionRecord>()).first(where: { $0.id == id }) else { throw CatalogError.versionNotFound }; return value }
    private func currentVersion(_ exercise: ExerciseRecord) -> ExerciseVersionRecord? { (exercise.versions ?? []).first { $0.id == exercise.currentVersionID } }
    private func clone(_ source: ExerciseLocalizationRecord, versionID: UUID) -> ExerciseLocalizationRecord { let value = ExerciseLocalizationRecord(id: uuid.makeUUID(), exerciseVersionID: versionID, localeIdentifier: source.localeIdentifier); value.title = source.title; value.goal = source.goal; value.setup = source.setup; value.steps = source.steps; value.successCriteria = source.successCriteria; value.commonErrors = source.commonErrors; value.regression = source.regression; value.progression = source.progression; value.homework = source.homework; value.safetyNotes = source.safetyNotes; value.reviewStatusRawValue = ContentReviewStatus.draft.rawValue; return value }
    private static func localization(_ value: ExerciseLocalizationRecord) -> ExerciseLocalizationDraft {
        let issues = ExerciseSupplementCodec.decode(value.commonErrors)
        return ExerciseLocalizationDraft(localeIdentifier: value.localeIdentifier, title: value.title, goal: value.goal, setup: value.setup, steps: value.steps, successCriteria: value.successCriteria, commonErrors: issues.problems, correctiveMeasures: issues.measures, regression: value.regression, progression: value.progression, homework: value.homework, safetyNotes: value.safetyNotes, reviewStatus: ContentReviewStatus(rawValue: value.reviewStatusRawValue) ?? .draft)
    }
    private func save() throws { if context.hasChanges { try context.save() } }
}
