import Foundation
import SwiftData

@MainActor
final class ContentPackImporter {
    private let context: ModelContext
    private let uuid: any UUIDGenerating
    init(context: ModelContext, uuid: any UUIDGenerating) { self.context = context; self.uuid = uuid }

    func importPack(data: Data) throws -> ContentPackDocument {
        let document = try ContentPackValidator.decodeAndValidate(data)
        let packs = try context.fetch(FetchDescriptor<ContentPackRecord>())
        if packs.contains(where: { $0.id == document.packID && $0.semanticVersion == document.packVersion }) { return document }

        let pack = packs.first(where: { $0.id == document.packID }) ?? ContentPackRecord(id: document.packID, semanticVersion: document.packVersion, titleKey: document.title)
        pack.author = document.author; pack.licenseMetadata = document.license; pack.minimumAppVersion = document.minimumAppVersion; pack.checksum = document.checksum
        pack.semanticVersion = document.packVersion; pack.titleKey = document.title
        if pack.modelContext == nil { context.insert(pack) }
        var versionsByExerciseID: [UUID: ExerciseVersionRecord] = [:]
        let storedExercises = try context.fetch(FetchDescriptor<ExerciseRecord>())
        for item in document.exercises {
            let exercise = storedExercises.first(where: { $0.id == item.id }) ?? ExerciseRecord(id: item.id, originRawValue: "editorial")
            exercise.contentPackID = pack.id; exercise.contentPack = pack
            if let current = (exercise.versions ?? []).first(where: { $0.id == exercise.currentVersionID }), current.versionNumber >= item.version {
                versionsByExerciseID[item.id] = current
                continue
            }
            let version = ExerciseVersionRecord(id: uuid.makeUUID(), exerciseID: exercise.id, versionNumber: item.version)
            version.durationMinutes = item.metadata.durationMinutes; version.difficultyRawValue = item.metadata.difficulty.rawValue; version.equipment = item.metadata.equipment; version.safetyLevelRawValue = item.metadata.safetyLevel.rawValue; version.publishedAt = .now; version.exercise = exercise
            version.localizations = item.localizations.sorted(by: { $0.key < $1.key }).map { locale, value in
                let record = ExerciseLocalizationRecord(id: uuid.makeUUID(), exerciseVersionID: version.id, localeIdentifier: locale)
                record.title = value.title; record.goal = value.goal; record.setup = value.setup; record.steps = value.steps; record.successCriteria = value.successCriteria
                record.commonErrors = ExerciseSupplementCodec.encode(problems: value.commonErrors, measures: value.correctiveMeasures)
                record.regression = value.regression; record.progression = value.progression; record.homework = value.homework; record.safetyNotes = value.safetyNotes; record.reviewStatusRawValue = value.reviewStatus.rawValue; record.exerciseVersion = version; context.insert(record); return record
            }
            version.supersedesVersionID = exercise.currentVersionID
            exercise.currentVersionID = version.id; exercise.versions = (exercise.versions ?? []) + [version]
            if exercise.modelContext == nil { context.insert(exercise) }
            context.insert(version); versionsByExerciseID[item.id] = version
        }
        pack.includedExerciseIDs = document.exercises.map(\.id)
        pack.exercises = try context.fetch(FetchDescriptor<ExerciseRecord>()).filter { $0.contentPackID == pack.id }

        let storedTemplates = try context.fetch(FetchDescriptor<TrainingTemplateRecord>())
        for item in document.templates {
            let template = storedTemplates.first(where: { $0.id == item.id }) ?? TrainingTemplateRecord(id: item.id)
            if let current = (template.versions ?? []).first(where: { $0.id == template.currentVersionID }), current.versionNumber >= item.version { continue }
            let version = TemplateVersionRecord(id: uuid.makeUUID(), templateID: template.id, versionNumber: item.version, title: item.title)
            version.targetDurationMinutes = item.targetDurationMinutes; version.audience = item.audience; version.trainerNotes = item.trainerNotes; version.publishedAt = .now; version.template = template
            version.exercises = item.exerciseItems.sorted(by: { $0.sortOrder < $1.sortOrder }).map { packed in
                let exerciseVersion = versionsByExerciseID[packed.exerciseID]!
                let record = TemplateExerciseRecord(id: uuid.makeUUID(), templateVersionID: version.id, exerciseVersionID: exerciseVersion.id, sortOrder: packed.sortOrder)
                record.plannedDurationMinutes = packed.plannedDurationMinutes; record.templateVersion = version; record.exerciseVersion = exerciseVersion; context.insert(record); return record
            }
            version.supersedesVersionID = template.currentVersionID
            template.currentVersionID = version.id; template.versions = (template.versions ?? []) + [version]
            if template.modelContext == nil { context.insert(template) }
            context.insert(version)
        }
        do { try context.save(); return document } catch { context.rollback(); throw AppError.persistence(operation: "content-pack.import") }
    }
}
