import Foundation

@MainActor
struct AppEnvironment {
    let persistence: any PersistenceProviding
    let clock: any AppClock
    let uuidGenerator: any UUIDGenerating
    let dataExporter: any DataExporting
    let diagnostics: any DiagnosticRecording

    static func live() throws -> AppEnvironment {
        let container = try ModelContainerFactory.makeDefault()
        let environment = AppEnvironment(
            persistence: PersistenceProvider(container: container),
            clock: SystemAppClock(),
            uuidGenerator: SystemUUIDGenerator(),
            dataExporter: UnavailableDataExporter(),
            diagnostics: DiagnosticRecorder()
        )
        try DemoDataSeeder.seedIfNeeded(
            context: container.mainContext,
            clock: environment.clock,
            uuidGenerator: environment.uuidGenerator
        )
        return environment
    }

    static func preview() throws -> AppEnvironment {
        let clock = FixedAppClock(date: Date(timeIntervalSince1970: 1_700_000_000))
        let container = try ModelContainerFactory.makeInMemory()
        let environment = AppEnvironment(
            persistence: PersistenceProvider(container: container),
            clock: clock,
            uuidGenerator: FixedUUIDGenerator(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!),
            dataExporter: UnavailableDataExporter(),
            diagnostics: DiagnosticRecorder(clock: clock)
        )
        try DemoDataSeeder.seedIfNeeded(
            context: container.mainContext,
            clock: environment.clock,
            uuidGenerator: environment.uuidGenerator
        )
        return environment
    }

    static func uiTesting() throws -> AppEnvironment {
        let container = try ModelContainerFactory.makeInMemory()
        let environment = AppEnvironment(
            persistence: PersistenceProvider(container: container),
            clock: SystemAppClock(),
            uuidGenerator: SystemUUIDGenerator(),
            dataExporter: UnavailableDataExporter(),
            diagnostics: DiagnosticRecorder()
        )
        try DemoDataSeeder.seedIfNeeded(
            context: container.mainContext,
            clock: environment.clock,
            uuidGenerator: environment.uuidGenerator
        )
        return environment
    }
}
