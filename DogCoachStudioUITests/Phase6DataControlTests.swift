import XCTest

final class Phase6DataControlTests: XCTestCase {
    @MainActor
    func testExportAndPrivacyControlsAtAccessibilitySize() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--phase6-uitesting", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["dataControlRoot"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["appLockToggle"].exists)
        app.buttons["dataExportButton"].tap()
        XCTAssertTrue(app.staticTexts["dataExportStatus"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["deletionPolicySummary"].exists)
    }

    @MainActor
    func testEnabledLockHidesApplicationContent() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--phase6-uitesting", "--lock-enabled"]
        app.launch()
        XCTAssertFalse(app.buttons["dataExportButton"].waitForExistence(timeout: 3))
    }
}
