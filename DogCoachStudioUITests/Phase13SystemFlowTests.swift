import XCTest

final class Phase13SystemFlowTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testDogRenameIsImmediatelyVisibleAcrossTabsAndDemoIsGone() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["appRootTabs"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Completion demo"].exists)

        app.buttons["Sessions"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["sessionsRoot"].waitForExistence(timeout: 3))
        app.buttons["People"].firstMatch.tap()

        let dogRow = app.buttons["Demo dog, owner Demo client"]
        XCTAssertTrue(dogRow.waitForExistence(timeout: 3))
        dogRow.tap()
        let edit = app.buttons["dogEditButton"]
        XCTAssertTrue(edit.waitForExistence(timeout: 3))
        edit.tap()

        let name = app.textFields["dogNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8))
        let renamed = "Fresh Dog \(UUID().uuidString.prefix(6))"
        name.typeText(renamed)
        app.buttons["dogSaveButton"].tap()

        app.buttons["Sessions"].firstMatch.tap()
        let add = app.buttons["sessionAddButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 3))
        add.tap()
        XCTAssertTrue(app.switches[renamed].waitForExistence(timeout: 3))
        XCTAssertFalse(app.switches["Demo dog"].exists)
    }
}
