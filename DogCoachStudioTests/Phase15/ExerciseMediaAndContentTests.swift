import Foundation
import SwiftData
import Testing
@testable import DogCoachStudio

@Suite("Phase 15 exercise media and enriched guidance")
struct ExerciseMediaAndContentTests {
    @Test("Problem and corrective measure survive repository roundtrip") @MainActor
    func correctiveMeasureRoundtrip() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataExerciseRepository(context: container.mainContext, uuid: SystemUUIDGenerator())
        let localization = ExerciseLocalizationDraft(
            localeIdentifier: "en",
            title: "Orientation",
            successCriteria: ["Three voluntary check-ins"],
            commonErrors: ["Calling continuously"],
            correctiveMeasures: ["Wait quietly and mark voluntary movement"]
        )
        let exerciseID = try repository.create(ExerciseDraft(durationMinutes: 5, localizations: [localization]))
        let (_, restored) = try repository.editableDraft(exerciseID: exerciseID)
        let content = try #require(restored.localizations.first)

        #expect(content.successCriteria == ["Three voluntary check-ins"])
        #expect(content.commonErrors == ["Calling continuously"])
        #expect(content.correctiveMeasures == ["Wait quietly and mark voluntary movement"])
    }

    @Test("Legacy problems without a measure remain readable")
    func legacyProblemCompatibility() {
        let decoded = ExerciseSupplementCodec.decode(["Calling continuously"])
        #expect(decoded.problems == ["Calling continuously"])
        #expect(decoded.measures == [""])
    }

    @Test("Photo manifest and protected file persist and delete together")
    func photoLifecycle() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "DogCoachStudio-Phase15-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = try ExerciseMediaLibrary(rootDirectory: root, uuid: SystemUUIDGenerator())
        let exerciseID = UUID()
        let onePixelPNG = try #require(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="))

        let asset = try await library.addPhoto(data: onePixelPNG, exerciseID: exerciseID)
        #expect(asset.kind == .photo)
        #expect(FileManager.default.fileExists(atPath: library.fileURL(for: asset).path))
        #expect(try await library.assets(exerciseID: exerciseID) == [asset])

        let reopened = try ExerciseMediaLibrary(rootDirectory: root, uuid: SystemUUIDGenerator())
        #expect(try await reopened.assets(exerciseID: exerciseID) == [asset])
        try await reopened.remove(asset)
        #expect(try await reopened.assets(exerciseID: exerciseID).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: reopened.fileURL(for: asset).path))
    }

    @Test("Foundation 1.1 provides a corrective measure for every listed problem")
    func foundationPackIsEnriched() throws {
        let url = try #require(Bundle.main.url(forResource: "foundation-v1", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let pack = try ContentPackValidator.decodeAndValidate(data)

        #expect(pack.packVersion == "1.1.0")
        #expect(pack.exercises.allSatisfy { exercise in
            exercise.version == 2 && exercise.localizations.values.allSatisfy {
                !$0.successCriteria.isEmpty && $0.commonErrors.count == $0.correctiveMeasures.count && $0.correctiveMeasures.allSatisfy { !$0.isEmpty }
            }
        })
    }
}
