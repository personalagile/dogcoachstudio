import XCTest

final class Phase5PackagesFlowTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor func testPackageListAndCreation() {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--phase5-uitesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]; app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["packagesRoot"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["packageRow"].firstMatch.waitForExistence(timeout: 3))
        app.buttons["packageAddButton"].tap(); let name = app.textFields["packageNameField"]; XCTAssertTrue(name.waitForExistence(timeout: 3)); name.tap(); name.typeText("UI package")
        app.buttons["packageDogPicker"].tap(); app.buttons["Demo dog"].tap(); app.buttons["packageSaveButton"].tap()
        XCTAssertTrue(app.staticTexts["UI package"].waitForExistence(timeout: 3))
    }
}
