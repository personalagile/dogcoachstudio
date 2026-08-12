import Foundation
import LocalAuthentication
import Observation

enum AppLockError: Error, Equatable, Sendable {
    case unavailable
    case authenticationFailed
}

protocol AppLockAuthenticating: Sendable {
    func canAuthenticate() async -> Bool
    func authenticate(reason: String) async throws
}

struct LocalAppLockAuthenticator: AppLockAuthenticating {
    func canAuthenticate() async -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    func authenticate(reason: String) async throws {
        let context = LAContext()
        context.localizedCancelTitle = String(localized: "Cancel")
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { throw AppLockError.unavailable }
        do {
            guard try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) else {
                throw AppLockError.authenticationFailed
            }
        } catch { throw AppLockError.authenticationFailed }
    }
}

@MainActor @Observable
final class AppLockModel {
    var isEnabled: Bool
    private(set) var isLocked: Bool
    private(set) var errorMessage: String?
    private let authenticator: any AppLockAuthenticating

    init(isEnabled: Bool, authenticator: any AppLockAuthenticating = LocalAppLockAuthenticator()) {
        self.isEnabled = isEnabled
        self.isLocked = isEnabled
        self.authenticator = authenticator
    }

    func movedToBackground() {
        guard isEnabled else { return }
        isLocked = true
        errorMessage = nil
    }

    func unlock() async {
        guard isEnabled else { isLocked = false; return }
        guard await authenticator.canAuthenticate() else {
            errorMessage = String(localized: "Device authentication is unavailable. Disable the lock in system settings or configure a passcode.")
            return
        }
        do {
            try await authenticator.authenticate(reason: String(localized: "Unlock DogCoach Studio"))
            isLocked = false
            errorMessage = nil
        } catch {
            isLocked = true
            errorMessage = String(localized: "Authentication failed. Try again or use the device passcode.")
        }
    }
}
