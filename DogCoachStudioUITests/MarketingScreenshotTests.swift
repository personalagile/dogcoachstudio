import XCTest

final class MarketingScreenshotTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testCaptureApprovedStory() {
        for locale in ["en", "de"] {
            captureRoot(locale: locale, name: "01-plan", arguments: ["--phase3-uitesting"], readyID: "catalogRoot")
            captureRoot(locale: locale, name: "02-attendance", arguments: ["--phase4-uitesting"], readyID: "sessionsRoot")
            captureCompletionReview(locale: locale, name: "03-exceptions")
            captureRoot(locale: locale, name: "04-dog-history", arguments: [], readyID: "appRootTabs")
            captureRoot(locale: locale, name: "05-package", arguments: ["--phase5-uitesting"], readyID: "packagesRoot")
            captureCompletionResult(locale: locale, name: "06-report")
        }
    }

    @MainActor
    private func captureRoot(locale: String, name: String, arguments: [String], readyID: String) {
        let app = launch(locale: locale, arguments: arguments)
        XCTAssertTrue(app.descendants(matching: .any)[readyID].waitForExistence(timeout: 5))
        attach(app.screenshot(), locale: locale, name: name)
        app.terminate()
    }

    @MainActor
    private func captureCompletionReview(locale: String, name: String) {
        let app = launch(locale: locale, arguments: ["--phase0-demo"])
        XCTAssertTrue(app.descendants(matching: .any)["sessionCompletionFlow"].waitForExistence(timeout: 5))
        for _ in 0..<3 { app.buttons["continueButton"].tap() }
        XCTAssertTrue(app.descendants(matching: .any)["completionReview"].waitForExistence(timeout: 3))
        attach(app.screenshot(), locale: locale, name: name)
        app.terminate()
    }

    @MainActor
    private func captureCompletionResult(locale: String, name: String) {
        let app = launch(locale: locale, arguments: ["--phase0-demo"])
        XCTAssertTrue(app.descendants(matching: .any)["sessionCompletionFlow"].waitForExistence(timeout: 5))
        for _ in 0..<3 { app.buttons["continueButton"].tap() }
        app.buttons["completeSessionButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["completionSuccess"].waitForExistence(timeout: 5))
        attach(app.screenshot(), locale: locale, name: name)
        app.terminate()
    }

    @MainActor
    private func launch(locale: String, arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-AppleLanguages", "(\(locale))", "-AppleLocale", locale == "de" ? "de_DE" : "en_US"] + arguments
        app.launch()
        return app
    }

    private func attach(_ screenshot: XCUIScreenshot, locale: String, name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "\(locale)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
