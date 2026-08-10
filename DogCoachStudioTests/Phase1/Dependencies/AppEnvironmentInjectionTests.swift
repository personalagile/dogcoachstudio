import Foundation
import Testing
@testable import DogCoachStudio

@Suite("Phase 1 dependency injection")
struct AppEnvironmentInjectionTests {
    @Test("Injected clock, UUID generator, exporter, and diagnostics are used")
    @MainActor
    func injectedDependenciesAreObservable() async throws {
        let date = Date(timeIntervalSince1970: 1_750_000_000)
        let uuid = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000042"))
        let artifact = ExportArtifact(
            suggestedFilename: "fixture.json",
            contentTypeIdentifier: "public.json",
            data: Data("fixture".utf8)
        )
        let diagnostics = DiagnosticSpy()
        let persistence = PersistenceProvider(container: try ModelContainerFactory.makeInMemory())
        let environment = AppEnvironment(
            persistence: persistence,
            clock: FixedAppClock(date: date),
            uuidGenerator: FixedUUIDGenerator(uuid: uuid),
            dataExporter: ExporterStub(artifact: artifact),
            diagnostics: diagnostics
        )

        #expect(environment.clock.now() == date)
        #expect(environment.uuidGenerator.makeUUID() == uuid)
        #expect(try await environment.dataExporter.export() == artifact)

        await environment.diagnostics.record(category: .app, code: .appLaunched)
        #expect(await diagnostics.recordedEvents() == [.init(category: .app, code: .appLaunched)])
    }

    @Test("Preview dependencies are deterministic")
    @MainActor
    func previewIsDeterministic() throws {
        let first = try AppEnvironment.preview()
        let second = try AppEnvironment.preview()

        #expect(first.clock.now() == second.clock.now())
        #expect(first.uuidGenerator.makeUUID() == second.uuidGenerator.makeUUID())
    }
}

private struct ExporterStub: DataExporting {
    let artifact: ExportArtifact

    func export() async throws -> ExportArtifact { artifact }
}

private actor DiagnosticSpy: DiagnosticRecording {
    struct Event: Equatable, Sendable {
        let category: DiagnosticCategory
        let code: DiagnosticEventCode
    }

    private var events: [Event] = []

    func record(category: DiagnosticCategory, code: DiagnosticEventCode) {
        events.append(Event(category: category, code: code))
    }

    func export() throws -> ExportArtifact {
        ExportArtifact(
            suggestedFilename: "spy.json",
            contentTypeIdentifier: "public.json",
            data: Data()
        )
    }

    func recordedEvents() -> [Event] { events }
}
