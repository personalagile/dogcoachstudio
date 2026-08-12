import Foundation
import SwiftData
import Testing
@testable import DogCoachStudio

@Suite("Phase 3 catalog and content packs")
struct CatalogPhase3Tests {
    @Test("Published exercise is immutable and editing creates version 2") @MainActor
    func exerciseVersioning() throws {
        let fixture = try Fixture()
        let id = try fixture.exercises.create(.sample(title: "Orientation"))
        let first = try #require(try fixture.exercises.search("", locale: "en", includeArchived: false).first)
        try fixture.exercises.publish(versionID: first.versionID, at: .now)
        #expect(throws: CatalogError.publishedVersionImmutable) { try fixture.exercises.updateDraft(versionID: first.versionID, draft: .sample(title: "Changed")) }
        let secondID = try fixture.exercises.createDraftVersion(exerciseID: id)
        try fixture.exercises.updateDraft(versionID: secondID, draft: .sample(title: "Changed"))
        let second = try #require(try fixture.exercises.search("changed", locale: "en", includeArchived: false).first)
        #expect(second.versionNumber == 2)
    }

    @Test("Locale fallback is deterministic and visible")
    func localeFallback() throws {
        let en = ExerciseLocalizationDraft(localeIdentifier: "en", title: "English")
        let de = ExerciseLocalizationDraft(localeIdentifier: "de", title: "Deutsch")
        let resolved = try #require(ExerciseLocaleResolver.resolve([de, en], requestedLocale: "fr-FR"))
        #expect(resolved.resolvedLocale == "en")
        #expect(resolved.isFallback)
    }

    @Test("Regional locale resolves its language without a fallback warning")
    func regionalLocaleIsNotFallback() throws {
        let de = ExerciseLocalizationDraft(localeIdentifier: "de", title: "Deutsch")
        let resolved = try #require(ExerciseLocaleResolver.resolve([de], requestedLocale: "de-DE"))
        #expect(resolved.resolvedLocale == "de")
        #expect(!resolved.isFallback)
    }

    @Test("Template order, duration and immutable version are preserved") @MainActor
    func templateVersioning() throws {
        let fixture = try Fixture()
        let a = try fixture.exercises.create(.sample(title: "A")); let b = try fixture.exercises.create(.sample(title: "B"))
        let versions = try fixture.exercises.search("", locale: "en", includeArchived: false)
        let draft = TrainingTemplateDraft(title: "Lesson", targetDurationMinutes: 10, audience: "Group", trainerNotes: nil, exercises: [
            .init(id: UUID(), exerciseVersionID: versions.first(where: { $0.id == b })!.versionID, plannedDurationMinutes: 6, trainerInstruction: nil),
            .init(id: UUID(), exerciseVersionID: versions.first(where: { $0.id == a })!.versionID, plannedDurationMinutes: 4, trainerInstruction: nil)
        ])
        let id = try fixture.templates.create(draft); let first = try #require(try fixture.templates.summaries().first)
        #expect(first.plannedDurationMinutes == first.targetDurationMinutes)
        try fixture.templates.publish(versionID: first.versionID, at: .now)
        #expect(throws: TemplateError.publishedVersionImmutable) { try fixture.templates.updateDraft(versionID: first.versionID, draft: draft) }
        _ = try fixture.templates.createDraftVersion(templateID: id)
        #expect(try fixture.templates.summaries().first?.versionNumber == 2)
    }

    @Test("Approved bundled pack validates and imports exactly once") @MainActor
    func packImport() throws {
        let fixture = try Fixture()
        let url = try #require(Bundle.main.url(forResource: "foundation-v1", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(ContentPackDocument.self, from: data)
        #expect(ContentPackValidator.checksum(for: data) == decoded.checksum)
        let document = try ContentPackValidator.decodeAndValidate(data)
        #expect(document.exercises.count == 5); #expect(document.templates.count == 2)
        _ = try ContentPackImporter(context: fixture.context, uuid: SystemUUIDGenerator()).importPack(data: data)
        _ = try ContentPackImporter(context: fixture.context, uuid: SystemUUIDGenerator()).importPack(data: data)
        #expect(try fixture.context.fetchCount(FetchDescriptor<ExerciseRecord>()) == 5)
        #expect(try fixture.context.fetchCount(FetchDescriptor<TrainingTemplateRecord>()) == 2)
    }

    @Test("Tampered pack is rejected before domain mutation") @MainActor
    func atomicRejection() throws {
        let fixture = try Fixture()
        let url = try #require(Bundle.main.url(forResource: "foundation-v1", withExtension: "json"))
        let original = try Data(contentsOf: url)
        let tampered = Data(String(decoding: original, as: UTF8.self).replacingOccurrences(of: "Voluntary orientation", with: "Tampered orientation").utf8)
        #expect(throws: ContentPackError.checksumMismatch) { try ContentPackImporter(context: fixture.context, uuid: SystemUUIDGenerator()).importPack(data: tampered) }
        #expect(try fixture.context.fetchCount(FetchDescriptor<ExerciseRecord>()) == 0)
    }
}

@MainActor private struct Fixture {
    let container: ModelContainer; let context: ModelContext; let exercises: SwiftDataExerciseRepository; let templates: SwiftDataTrainingTemplateRepository
    init() throws { container = try ModelContainerFactory.makeInMemory(); context = container.mainContext; exercises = .init(context: context, uuid: SystemUUIDGenerator()); templates = .init(context: context, uuid: SystemUUIDGenerator()) }
}
private extension ExerciseDraft {
    static func sample(title: String) -> Self { .init(durationMinutes: 5, equipment: ["mat"], localizations: [.init(localeIdentifier: "en", title: title, goal: "Calm focus")]) }
}
