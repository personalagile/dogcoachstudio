import Foundation
import Testing
@testable import DogCoachStudio

@Suite("Phase 1 diagnostic export")
struct DiagnosticExportTests {
    @Test("Diagnostic export is deterministic and contains only structured event fields")
    func exportContainsStructuredNonPIIEvents() async throws {
        let date = Date(timeIntervalSince1970: 1_750_000_000)
        let recorder = DiagnosticRecorder(clock: FixedAppClock(date: date))

        await recorder.record(category: .persistence, code: .persistenceOperationFailed)
        await recorder.record(category: .completion, code: .validationFailed)
        let artifact = try await recorder.export()
        let events = try JSONDecoder.iso8601.decode([DiagnosticEvent].self, from: artifact.data)

        #expect(artifact.suggestedFilename == "dogcoach-diagnostics.json")
        #expect(artifact.contentTypeIdentifier == "public.json")
        #expect(events == [
            DiagnosticEvent(occurredAt: date, category: .persistence, code: .persistenceOperationFailed),
            DiagnosticEvent(occurredAt: date, category: .completion, code: .validationFailed)
        ])

        let json = try #require(String(data: artifact.data, encoding: .utf8))
        for forbiddenKey in ["name", "email", "phone", "note", "body", "address"] {
            #expect(!json.localizedCaseInsensitiveContains("\"\(forbiddenKey)\""))
        }
    }

    @Test("Empty diagnostics still produce a valid JSON export")
    func emptyExport() async throws {
        let artifact = try await DiagnosticRecorder().export()
        #expect(try JSONDecoder.iso8601.decode([DiagnosticEvent].self, from: artifact.data).isEmpty)
    }

    @Test("Error metadata cannot leak associated PII into diagnostics")
    func associatedValuesAreExcludedFromDiagnosticCodes() {
        let piiCanary = "person@example.test / Private trainer note"
        let errors: [AppError] = [
            .validation(code: piiCanary),
            .persistence(operation: piiCanary),
            .featureUnavailable(feature: piiCanary),
            .unexpected(code: piiCanary)
        ]

        #expect(errors.allSatisfy { !$0.diagnosticCode.rawValue.contains(piiCanary) })
        #expect(errors.map(\.diagnosticCode) == [
            .validationFailed,
            .persistenceOperationFailed,
            .featureUnavailable,
            .unexpectedFailure
        ])
    }
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
