import Foundation
import OSLog

enum DiagnosticCategory: String, Codable, Sendable {
    case app
    case persistence
    case completion
    case export
}

enum DiagnosticEventCode: String, Codable, Sendable {
    case appLaunched = "app.launched"
    case validationFailed = "validation.failed"
    case persistenceOpened = "persistence.opened"
    case persistenceOperationFailed = "persistence.operation-failed"
    case dataCorrupted = "data.corrupted"
    case featureUnavailable = "feature.unavailable"
    case completionSucceeded = "completion.succeeded"
    case exportSucceeded = "export.succeeded"
    case unexpectedFailure = "unexpected.failure"
}

struct DiagnosticEvent: Codable, Equatable, Sendable {
    let occurredAt: Date
    let category: DiagnosticCategory
    let code: DiagnosticEventCode
}

protocol DiagnosticRecording: Sendable {
    func record(category: DiagnosticCategory, code: DiagnosticEventCode) async
    func export() async throws -> ExportArtifact
}

actor DiagnosticRecorder: DiagnosticRecording {
    private let clock: any AppClock
    private var events: [DiagnosticEvent] = []

    init(clock: any AppClock = SystemAppClock()) {
        self.clock = clock
    }

    func record(category: DiagnosticCategory, code: DiagnosticEventCode) {
        events.append(DiagnosticEvent(occurredAt: clock.now(), category: category, code: code))
        AppLogger.log(category: category, code: code)
    }

    func export() throws -> ExportArtifact {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return ExportArtifact(
            suggestedFilename: "dogcoach-diagnostics.json",
            contentTypeIdentifier: "public.json",
            data: try encoder.encode(events)
        )
    }
}

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "studio.dogcoach"

    static func log(category: DiagnosticCategory, code: DiagnosticEventCode) {
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        logger.info("Event code: \(code.rawValue, privacy: .public)")
    }
}
