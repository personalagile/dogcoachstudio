import Foundation

enum RecoveryAction: String, Codable, Equatable, Sendable {
    case retry
    case reviewInput
    case freeStorage
    case contactSupport
    case none
}

enum AppError: Error, Equatable, Sendable {
    case validation(code: String)
    case persistence(operation: String)
    case corruptedData
    case featureUnavailable(feature: String)
    case unexpected(code: String)

    var diagnosticCode: DiagnosticEventCode {
        switch self {
        case .validation: .validationFailed
        case .persistence: .persistenceOperationFailed
        case .corruptedData: .dataCorrupted
        case .featureUnavailable: .featureUnavailable
        case .unexpected: .unexpectedFailure
        }
    }

    var recoveryAction: RecoveryAction {
        switch self {
        case .validation: .reviewInput
        case .persistence: .retry
        case .corruptedData: .contactSupport
        case .featureUnavailable: .none
        case .unexpected: .contactSupport
        }
    }

    var userMessage: String {
        switch self {
        case .validation:
            String(localized: "Please review the highlighted information.", comment: "Recovery message for invalid form data")
        case .persistence:
            String(localized: "Your changes could not be saved. Please try again.", comment: "Recovery message for a local persistence failure")
        case .corruptedData:
            String(localized: "Some local data could not be read.", comment: "Message for unreadable local data")
        case .featureUnavailable:
            String(localized: "This feature is not available yet.", comment: "Message for a feature outside the current release")
        case .unexpected:
            String(localized: "Something went wrong. Please try again.", comment: "Fallback error message")
        }
    }
}

enum AppErrorMapper {
    static func map(_ error: any Error, operation: String) -> AppError {
        if let appError = error as? AppError { return appError }
        if error is DecodingError { return .corruptedData }
        return .unexpected(code: operation)
    }
}
