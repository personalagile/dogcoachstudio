import Foundation

protocol AppClock: Sendable {
    func now() -> Date
}

struct SystemAppClock: AppClock {
    func now() -> Date { .now }
}

struct FixedAppClock: AppClock {
    let date: Date

    func now() -> Date { date }
}

protocol UUIDGenerating: Sendable {
    func makeUUID() -> UUID
}

struct SystemUUIDGenerator: UUIDGenerating {
    func makeUUID() -> UUID { UUID() }
}

struct FixedUUIDGenerator: UUIDGenerating {
    let uuid: UUID

    func makeUUID() -> UUID { uuid }
}

struct ExportArtifact: Equatable, Sendable {
    let suggestedFilename: String
    let contentTypeIdentifier: String
    let data: Data
}

protocol DataExporting: Sendable {
    func export() async throws -> ExportArtifact
}

struct UnavailableDataExporter: DataExporting {
    func export() async throws -> ExportArtifact {
        throw AppError.featureUnavailable(feature: "data-export")
    }
}

