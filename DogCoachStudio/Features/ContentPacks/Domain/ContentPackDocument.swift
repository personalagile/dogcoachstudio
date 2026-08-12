import CryptoKit
import Foundation

struct ContentPackDocument: Decodable, Sendable {
    let schemaVersion: Int
    let packID: UUID
    let packSlug: String
    let packVersion: String
    let title: String
    let author: String
    let license: String
    let reviewStatus: ContentReviewStatus
    let minimumAppVersion: String
    let methodologyNote: String
    let exercises: [PackedExercise]
    let templates: [PackedTemplate]
    let checksum: String
}

struct PackedExercise: Decodable, Sendable {
    struct Metadata: Decodable, Sendable { let categories: [String]; let difficulty: ExerciseDifficulty; let durationMinutes: Int; let equipment: [String]; let safetyLevel: ExerciseSafetyLevel }
    let id: UUID; let version: Int; let metadata: Metadata; let localizations: [String: ExerciseLocalizationDraft]

    private struct LocalizationPayload: Decodable {
        let title: String; let goal: String; let setup: String; let steps: [String]; let successCriteria: [String]; let commonErrors: [String]; let correctiveMeasures: [String]?
        let regression: String; let progression: String; let homework: String; let safetyNotes: String; let reviewStatus: ContentReviewStatus
    }

    private enum CodingKeys: String, CodingKey { case id, version, metadata, localizations }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id); version = try values.decode(Int.self, forKey: .version); metadata = try values.decode(Metadata.self, forKey: .metadata)
        let payloads = try values.decode([String: LocalizationPayload].self, forKey: .localizations)
        let drafts = payloads.mapValues { value in
            ExerciseLocalizationDraft(localeIdentifier: "", title: value.title, goal: value.goal, setup: value.setup, steps: value.steps, successCriteria: value.successCriteria, commonErrors: value.commonErrors, correctiveMeasures: value.correctiveMeasures ?? [], regression: value.regression, progression: value.progression, homework: value.homework, safetyNotes: value.safetyNotes, reviewStatus: value.reviewStatus)
        }
        localizations = Dictionary(uniqueKeysWithValues: drafts.map { key, value in
            var localized = value; localized.localeIdentifier = key; return (key, localized)
        })
    }
}
struct PackedTemplate: Decodable, Sendable {
    struct Item: Decodable, Sendable { let exerciseID: UUID; let sortOrder: Int; let plannedDurationMinutes: Int }
    let id: UUID; let version: Int; let title: String; let audience: String; let targetDurationMinutes: Int; let trainerNotes: String?; let exerciseItems: [Item]; let reviewStatus: ContentReviewStatus
}

enum ContentPackError: Error, Equatable { case malformed, unsupportedSchema, invalidSemanticVersion, missingMetadata, notApproved, missingRequiredLocale, unsupportedRiskLevel, duplicateID, invalidReference, durationMismatch, checksumMismatch }

enum ContentPackValidator {
    static func decodeAndValidate(_ data: Data) throws -> ContentPackDocument {
        guard let pack = try? JSONDecoder().decode(ContentPackDocument.self, from: data) else { throw ContentPackError.malformed }
        guard pack.schemaVersion == 1 else { throw ContentPackError.unsupportedSchema }
        guard pack.packVersion.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression) != nil else { throw ContentPackError.invalidSemanticVersion }
        guard !pack.author.isEmpty, !pack.license.isEmpty, !pack.methodologyNote.isEmpty else { throw ContentPackError.missingMetadata }
        guard pack.reviewStatus == .approved, pack.exercises.allSatisfy({ $0.localizations.values.allSatisfy { $0.reviewStatus == .approved } }), pack.templates.allSatisfy({ $0.reviewStatus == .approved }) else { throw ContentPackError.notApproved }
        guard pack.exercises.allSatisfy({ Set($0.localizations.keys) == Set(["de", "en"]) }) else { throw ContentPackError.missingRequiredLocale }
        guard pack.exercises.allSatisfy({ $0.metadata.safetyLevel == .standard }) else { throw ContentPackError.unsupportedRiskLevel }
        guard Set(pack.exercises.map(\.id)).count == pack.exercises.count, Set(pack.templates.map(\.id)).count == pack.templates.count else { throw ContentPackError.duplicateID }
        let exerciseIDs = Set(pack.exercises.map(\.id))
        guard pack.templates.flatMap(\.exerciseItems).allSatisfy({ exerciseIDs.contains($0.exerciseID) }) else { throw ContentPackError.invalidReference }
        guard pack.templates.allSatisfy({ $0.exerciseItems.map(\.plannedDurationMinutes).reduce(0,+) == $0.targetDurationMinutes }) else { throw ContentPackError.durationMismatch }
        guard checksum(for: data) == pack.checksum else { throw ContentPackError.checksumMismatch }
        return pack
    }

    static func checksum(for data: Data) -> String? {
        guard var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        object.removeValue(forKey: "checksum")
        guard let canonical = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return nil }
        return SHA256.hash(data: canonical).map { String(format: "%02x", $0) }.joined()
    }
}
