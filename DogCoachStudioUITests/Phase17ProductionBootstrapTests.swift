import XCTest

final class Phase17ProductionBootstrapTests: XCTestCase {
    @MainActor
    func testEmptyProductionStartContainsNoAutomaticDemoPeople() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["onboardingStartEmptyButton"].waitForExistence(timeout: 5))
        app.buttons["onboardingStartEmptyButton"].tap()
        XCTAssertTrue(app.otherElements["appRootTabs"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Demo client"].exists)
        XCTAssertFalse(app.staticTexts["Demo dog"].exists)
    }

    @MainActor
    func testSampleDataRequiresExplicitChoice() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["onboardingLoadSampleButton"].waitForExistence(timeout: 5))
        app.buttons["onboardingLoadSampleButton"].tap()
        XCTAssertTrue(app.otherElements["appRootTabs"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Demo client"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--phase17-uitesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }
}
