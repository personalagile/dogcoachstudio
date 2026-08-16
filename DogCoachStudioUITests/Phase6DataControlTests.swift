import XCTest

final class Phase6DataControlTests: XCTestCase {
    @MainActor
    func testExportAndPrivacyControlsAtAccessibilitySize() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--phase6-uitesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["dataControlRoot"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["appLockToggle"].exists)
        app.buttons["dataExportButton"].tap()
        XCTAssertTrue(app.staticTexts["dataExportStatus"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["dataBackupShareLink"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["deletionPolicySummary"].exists)
        for _ in 0..<3 where !app.buttons["diagnosticsExportButton"].exists { app.swipeUp() }
        XCTAssertTrue(app.buttons["diagnosticsExportButton"].waitForExistence(timeout: 3))
        app.buttons["diagnosticsExportButton"].tap()
        XCTAssertTrue(app.buttons["diagnosticsShareLink"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testEnabledLockHidesApplicationContent() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--phase6-uitesting", "--lock-enabled", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["appLockedView"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["dataExportButton"].waitForExistence(timeout: 3))
    }
}
