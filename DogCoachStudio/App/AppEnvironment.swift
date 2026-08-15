import Foundation
import Observation

@MainActor
@Observable
final class AppDataChanges {
    private(set) var revision = 0

    func notify() {
        revision &+= 1
    }
}

@MainActor
struct AppEnvironment {
    let persistence: any PersistenceProviding
    let clock: any AppClock
    let uuidGenerator: any UUIDGenerating
    let dataExporter: any DataExporting
    let diagnostics: any DiagnosticRecording
    let dataChanges: AppDataChanges

    init(
        persistence: any PersistenceProviding,
        clock: any AppClock,
        uuidGenerator: any UUIDGenerating,
        dataExporter: any DataExporting,
        diagnostics: any DiagnosticRecording,
        dataChanges: AppDataChanges = AppDataChanges()
    ) {
        self.persistence = persistence
        self.clock = clock
        self.uuidGenerator = uuidGenerator
        self.dataExporter = dataExporter
        self.diagnostics = diagnostics
        self.dataChanges = dataChanges
    }

    static func live() throws -> AppEnvironment {
        let container = try ModelContainerFactory.makeDefault()
        let environment = AppEnvironment(
            persistence: PersistenceProvider(container: container),
            clock: SystemAppClock(),
            uuidGenerator: SystemUUIDGenerator(),
            dataExporter: UnavailableDataExporter(),
            diagnostics: DiagnosticRecorder()
        )
#if DEBUG
        try DemoDataSeeder.seedIfNeeded(
            context: container.mainContext,
            clock: environment.clock,
            uuidGenerator: environment.uuidGenerator
        )
#endif
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
#if DEBUG
        try DemoDataSeeder.seedIfNeeded(
            context: container.mainContext,
            clock: environment.clock,
            uuidGenerator: environment.uuidGenerator
        )
#endif
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
#if DEBUG
        if !ProcessInfo.processInfo.arguments.contains("--phase17-uitesting") {
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--phase4-uitesting") || arguments.contains("--phase5-uitesting") {
                try DemoDataSeeder.seedMinimalPeopleIfNeeded(
                    context: container.mainContext,
                    clock: environment.clock,
                    uuidGenerator: environment.uuidGenerator
                )
            } else {
                try DemoDataSeeder.seedIfNeeded(
                    context: container.mainContext,
                    clock: environment.clock,
                    uuidGenerator: environment.uuidGenerator
                )
            }
        }
#endif
        return environment
    }
}
