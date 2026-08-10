import Foundation
import SwiftData

@Model
final class ExerciseRecord {
    var id: UUID = UUID()
    var originRawValue: String = "private"
    var contentPackID: UUID?
    var currentVersionID: UUID?
    var categoryIDsData: Data = Data()
    @Transient var categoryIDs: [UUID] {
        get { CodableAttribute.decode([UUID].self, from: categoryIDsData) ?? [] }
        set { categoryIDsData = CodableAttribute.encode(newValue) }
    }
    var isArchived: Bool = false
    var versions: [ExerciseVersionRecord]?
    var contentPack: ContentPackRecord?

    init(id: UUID = UUID(), originRawValue: String = "private") {
        self.id = id
        self.originRawValue = originRawValue
    }
}

@Model
final class ExerciseVersionRecord {
    var id: UUID = UUID()
    var exerciseID: UUID = UUID()
    var versionNumber: Int = 1
    var durationMinutes: Int?
    var difficultyRawValue: String = "foundation"
    var equipmentData: Data = Data()
    @Transient var equipment: [String] {
        get { CodableAttribute.decode([String].self, from: equipmentData) ?? [] }
        set { equipmentData = CodableAttribute.encode(newValue) }
    }
    var safetyLevelRawValue: String = "standard"
    var publishedAt: Date?
    var supersedesVersionID: UUID?
    var exercise: ExerciseRecord?
    var localizations: [ExerciseLocalizationRecord]?

    init(id: UUID = UUID(), exerciseID: UUID, versionNumber: Int = 1) {
        self.id = id
        self.exerciseID = exerciseID
        self.versionNumber = versionNumber
    }
}

@Model
final class ExerciseLocalizationRecord {
    var id: UUID = UUID()
    var exerciseVersionID: UUID = UUID()
    var localeIdentifier: String = "en"
    var title: String = ""
    var goal: String = ""
    var setup: String = ""
    var stepsData: Data = Data()
    var successCriteriaData: Data = Data()
    var commonErrorsData: Data = Data()
    @Transient var steps: [String] {
        get { CodableAttribute.decode([String].self, from: stepsData) ?? [] }
        set { stepsData = CodableAttribute.encode(newValue) }
    }
    @Transient var successCriteria: [String] {
        get { CodableAttribute.decode([String].self, from: successCriteriaData) ?? [] }
        set { successCriteriaData = CodableAttribute.encode(newValue) }
    }
    @Transient var commonErrors: [String] {
        get { CodableAttribute.decode([String].self, from: commonErrorsData) ?? [] }
        set { commonErrorsData = CodableAttribute.encode(newValue) }
    }
    var regression: String = ""
    var progression: String = ""
    var homework: String = ""
    var safetyNotes: String = ""
    var reviewStatusRawValue: String = "draft"
    var exerciseVersion: ExerciseVersionRecord?

    init(id: UUID = UUID(), exerciseVersionID: UUID, localeIdentifier: String) {
        self.id = id
        self.exerciseVersionID = exerciseVersionID
        self.localeIdentifier = localeIdentifier
    }
}

@Model
final class TrainingTemplateRecord {
    var id: UUID = UUID()
    var currentVersionID: UUID?
    var isArchived: Bool = false
    var versions: [TemplateVersionRecord]?

    init(id: UUID = UUID()) { self.id = id }
}

@Model
final class TemplateVersionRecord {
    var id: UUID = UUID()
    var templateID: UUID = UUID()
    var versionNumber: Int = 1
    var title: String = ""
    var targetDurationMinutes: Int = 0
    var audience: String = ""
    var trainerNotes: String?
    var publishedAt: Date?
    var supersedesVersionID: UUID?
    var template: TrainingTemplateRecord?
    var exercises: [TemplateExerciseRecord]?

    init(id: UUID = UUID(), templateID: UUID, versionNumber: Int = 1, title: String) {
        self.id = id
        self.templateID = templateID
        self.versionNumber = versionNumber
        self.title = title
    }
}

@Model
final class TemplateExerciseRecord {
    var id: UUID = UUID()
    var templateVersionID: UUID = UUID()
    var exerciseVersionID: UUID = UUID()
    var sortOrder: Int = 0
    var plannedDurationMinutes: Int?
    var trainerInstruction: String?
    var templateVersion: TemplateVersionRecord?
    var exerciseVersion: ExerciseVersionRecord?

    init(id: UUID = UUID(), templateVersionID: UUID, exerciseVersionID: UUID, sortOrder: Int) {
        self.id = id
        self.templateVersionID = templateVersionID
        self.exerciseVersionID = exerciseVersionID
        self.sortOrder = sortOrder
    }
}

@Model
final class ContentPackRecord {
    var id: UUID = UUID()
    var semanticVersion: String = "0.0.0"
    var titleKey: String = ""
    var author: String = ""
    var licenseMetadata: String = ""
    var minimumAppVersion: String = ""
    var includedExerciseIDsData: Data = Data()
    @Transient var includedExerciseIDs: [UUID] {
        get { CodableAttribute.decode([UUID].self, from: includedExerciseIDsData) ?? [] }
        set { includedExerciseIDsData = CodableAttribute.encode(newValue) }
    }
    var entitlementID: String?
    var checksum: String = ""
    var exercises: [ExerciseRecord]?

    init(id: UUID = UUID(), semanticVersion: String, titleKey: String) {
        self.id = id
        self.semanticVersion = semanticVersion
        self.titleKey = titleKey
    }
}
