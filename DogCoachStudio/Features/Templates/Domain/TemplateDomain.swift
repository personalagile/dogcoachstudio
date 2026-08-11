import Foundation

struct TemplateExerciseDraft: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var exerciseVersionID: UUID
    var plannedDurationMinutes: Int?
    var trainerInstruction: String?
}

struct TrainingTemplateDraft: Equatable, Sendable {
    var title: String
    var targetDurationMinutes: Int
    var audience: String
    var trainerNotes: String?
    var exercises: [TemplateExerciseDraft]

    var plannedDurationMinutes: Int { exercises.compactMap(\.plannedDurationMinutes).reduce(0, +) }
    var durationDifference: Int { plannedDurationMinutes - targetDurationMinutes }
}

struct TrainingTemplateSummary: Identifiable, Equatable, Sendable {
    let id: UUID
    let versionID: UUID
    let versionNumber: Int
    let title: String
    let targetDurationMinutes: Int
    let plannedDurationMinutes: Int
    let exerciseCount: Int
    let isPublished: Bool
    let isArchived: Bool
}

enum TemplateError: Error, Equatable { case templateNotFound, versionNotFound, titleRequired, invalidDuration, duplicateExercise, publishedVersionImmutable }

enum TemplateValidator {
    static func validate(_ draft: TrainingTemplateDraft) throws {
        guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw TemplateError.titleRequired }
        guard draft.targetDurationMinutes > 0, draft.exercises.allSatisfy({ ($0.plannedDurationMinutes ?? 1) > 0 }) else { throw TemplateError.invalidDuration }
        guard Set(draft.exercises.map(\.exerciseVersionID)).count == draft.exercises.count else { throw TemplateError.duplicateExercise }
    }
}
