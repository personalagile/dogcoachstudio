import Foundation
import Testing
@testable import DogCoachStudio

@Suite("Phase 1 app error mapping")
struct AppErrorMappingTests {
    @Test("App errors retain their domain meaning")
    func appErrorPassesThrough() {
        let source = AppError.validation(code: "client.name")
        #expect(AppErrorMapper.map(source, operation: "save") == source)
    }

    @Test("Decoding failures map to corrupted data")
    func decodingErrorMapsToCorruptedData() {
        struct Payload: Decodable { let value: Int }
        let error: any Error
        do {
            _ = try JSONDecoder().decode(Payload.self, from: Data("{}".utf8))
            Issue.record("The malformed fixture unexpectedly decoded")
            return
        } catch let caught {
            error = caught
        }

        #expect(AppErrorMapper.map(error, operation: "import") == .corruptedData)
    }

    @Test("Unknown failures use a stable operation code")
    func unknownErrorMapsToUnexpected() {
        let source = NSError(domain: "test-only", code: 7)
        #expect(AppErrorMapper.map(source, operation: "load-clients") == .unexpected(code: "load-clients"))
    }

    @Test("Errors expose stable diagnostic and recovery metadata", arguments: errorCases)
    func metadata(testCase: ErrorCase) {
        #expect(testCase.error.diagnosticCode == testCase.diagnosticCode)
        #expect(testCase.error.recoveryAction == testCase.recoveryAction)
        #expect(!testCase.error.userMessage.isEmpty)
    }
}

struct ErrorCase: Sendable, CustomTestStringConvertible {
    let error: AppError
    let diagnosticCode: DiagnosticEventCode
    let recoveryAction: RecoveryAction
    var testDescription: String { diagnosticCode.rawValue }
}

let errorCases: [ErrorCase] = [
    .init(error: .validation(code: "required"), diagnosticCode: .validationFailed, recoveryAction: .reviewInput),
    .init(error: .persistence(operation: "save"), diagnosticCode: .persistenceOperationFailed, recoveryAction: .retry),
    .init(error: .corruptedData, diagnosticCode: .dataCorrupted, recoveryAction: .contactSupport),
    .init(error: .featureUnavailable(feature: "export"), diagnosticCode: .featureUnavailable, recoveryAction: .none),
    .init(error: .unexpected(code: "unknown"), diagnosticCode: .unexpectedFailure, recoveryAction: .contactSupport)
]
