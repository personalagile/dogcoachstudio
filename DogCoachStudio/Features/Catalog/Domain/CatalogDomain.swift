import Foundation

enum ContentReviewStatus: String, CaseIterable, Codable, Sendable { case draft, linguisticReview, expertReview, approved }
enum ExerciseDifficulty: String, CaseIterable, Codable, Sendable { case foundation, intermediate, advanced }
enum ExerciseSafetyLevel: String, CaseIterable, Codable, Sendable { case standard, caution }

struct ExerciseLocalizationDraft: Equatable, Codable, Sendable {
    var localeIdentifier: String
    var title = ""
    var goal = ""
    var setup = ""
    var steps: [String] = []
    var successCriteria: [String] = []
    var commonErrors: [String] = []
    var correctiveMeasures: [String] = []
    var regression = ""
    var progression = ""
    var homework = ""
    var safetyNotes = ""
    var reviewStatus: ContentReviewStatus = .draft
}

struct ExerciseProblemMeasure: Identifiable, Equatable, Codable, Sendable {
    var id: UUID
    var problem: String
    var measure: String

    init(id: UUID = UUID(), problem: String = "", measure: String = "") {
        self.id = id
        self.problem = problem
        self.measure = measure
    }
}

enum ExerciseMediaKind: String, Codable, Sendable { case photo, video }

struct ExerciseMediaAsset: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let exerciseID: UUID
    let kind: ExerciseMediaKind
    let fileName: String
    let createdAt: Date
}

enum ExerciseSupplementCodec {
    private static let marker = "\u{241E}DCS-MEASURE\u{241F}"

    static func encode(problems: [String], measures: [String]) -> [String] {
        problems.enumerated().map { index, problem in
            let measure = measures.indices.contains(index) ? measures[index] : ""
            return measure.isEmpty ? problem : problem + marker + measure
        }
    }

    static func decode(_ values: [String]) -> (problems: [String], measures: [String]) {
        let pairs = values.map { value -> (String, String) in
            guard let range = value.range(of: marker) else { return (value, "") }
            return (String(value[..<range.lowerBound]), String(value[range.upperBound...]))
        }
        return (pairs.map(\.0), pairs.map(\.1))
    }
}

struct ExerciseDraft: Equatable, Sendable {
    var durationMinutes: Int?
    var difficulty: ExerciseDifficulty = .foundation
    var equipment: [String] = []
    var safetyLevel: ExerciseSafetyLevel = .standard
    var categoryIDs: [UUID] = []
    var localizations: [ExerciseLocalizationDraft]
}

struct LocalizedExerciseContent: Equatable, Sendable {
    let content: ExerciseLocalizationDraft
    let requestedLocale: String
    let resolvedLocale: String
    let isFallback: Bool
}

struct ExerciseSummary: Identifiable, Equatable, Sendable {
    let id: UUID
    let versionID: UUID
    let versionNumber: Int
    let title: String
    let goal: String
    let durationMinutes: Int?
    let equipment: [String]
    let isPublished: Bool
    let isArchived: Bool
    let isStandardContent: Bool
    let localeResolution: LocalizedExerciseContent
}

enum CatalogError: Error, Equatable {
    case exerciseNotFound
    case versionNotFound
    case publishedVersionImmutable
    case titleRequired
    case localizationRequired
    case duplicateLocale(String)
    case invalidDuration
    case exerciseInUse
    case missingTranslation(requested: String)
}

enum ExerciseLocaleResolver {
    static func resolve(
        _ localizations: [ExerciseLocalizationDraft],
        requestedLocale: String,
        fallbackLocale: String = "en"
    ) -> LocalizedExerciseContent? {
        let requested = Locale(identifier: requestedLocale).language.languageCode?.identifier ?? requestedLocale
        let fallback = Locale(identifier: fallbackLocale).language.languageCode?.identifier ?? fallbackLocale
        let exact = localizations.first { $0.localeIdentifier == requestedLocale }
        let language = localizations.first { Locale(identifier: $0.localeIdentifier).language.languageCode?.identifier == requested }
        let fallbackMatch = localizations.first { Locale(identifier: $0.localeIdentifier).language.languageCode?.identifier == fallback }
        guard let value = exact ?? language ?? fallbackMatch ?? localizations.sorted(by: { $0.localeIdentifier < $1.localeIdentifier }).first else { return nil }
        let resolvedLanguage = Locale(identifier: value.localeIdentifier).language.languageCode?.identifier ?? value.localeIdentifier
        return LocalizedExerciseContent(
            content: value,
            requestedLocale: requestedLocale,
            resolvedLocale: value.localeIdentifier,
            isFallback: resolvedLanguage != requested
        )
    }
}

enum CatalogValidator {
    static func validate(_ draft: ExerciseDraft) throws {
        guard draft.durationMinutes.map({ $0 > 0 }) ?? true else { throw CatalogError.invalidDuration }
        guard !draft.localizations.isEmpty else { throw CatalogError.localizationRequired }
        var locales = Set<String>()
        for localization in draft.localizations {
            guard !localization.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw CatalogError.titleRequired }
            guard locales.insert(localization.localeIdentifier).inserted else { throw CatalogError.duplicateLocale(localization.localeIdentifier) }
        }
    }
}
