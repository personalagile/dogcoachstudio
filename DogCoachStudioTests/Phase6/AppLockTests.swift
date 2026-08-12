import Foundation
import Testing
@testable import DogCoachStudio

@Suite("Phase 6 app lock")
struct AppLockTests {
    @Test("Background locks and successful device authentication unlocks")
    @MainActor
    func backgroundAndUnlock() async {
        let model = AppLockModel(isEnabled: true, authenticator: FakeAuthenticator(available: true, succeeds: true))
        model.movedToBackground()
        #expect(model.isLocked)
        await model.unlock()
        #expect(!model.isLocked)
        #expect(model.errorMessage == nil)
    }

    @Test("Lockout keeps content locked and gives passcode fallback guidance")
    @MainActor
    func lockout() async {
        let model = AppLockModel(isEnabled: true, authenticator: FakeAuthenticator(available: true, succeeds: false))
        await model.unlock()
        #expect(model.isLocked)
        #expect(model.errorMessage != nil)
    }

    @Test("Unavailable device authentication never exposes content")
    @MainActor
    func unavailable() async {
        let model = AppLockModel(isEnabled: true, authenticator: FakeAuthenticator(available: false, succeeds: false))
        await model.unlock()
        #expect(model.isLocked)
        #expect(model.errorMessage != nil)
    }
}

private struct FakeAuthenticator: AppLockAuthenticating {
    let available: Bool
    let succeeds: Bool
    func canAuthenticate() async -> Bool { available }
    func authenticate(reason: String) async throws {
        if !succeeds { throw AppLockError.authenticationFailed }
    }
}
