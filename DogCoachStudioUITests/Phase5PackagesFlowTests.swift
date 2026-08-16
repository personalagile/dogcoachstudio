import XCTest

final class Phase5PackagesFlowTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor func testPackageListAndCreation() {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--phase5-uitesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]; app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["packagesRoot"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.searchFields.firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["packageRow"].firstMatch.waitForExistence(timeout: 3))
        app.buttons["packageAddButton"].tap(); app.buttons["Sell package"].tap()
        XCTAssertTrue(app.staticTexts["packageFormIntroduction"].waitForExistence(timeout: 3))
        app.buttons["packageClientPicker"].tap(); app.buttons["Demo client"].tap()
        app.swipeUp()
        XCTAssertTrue(app.descendants(matching: .any)["packageNameHelp"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["packageUnitsHelp"].exists)
        let name = app.textFields["packageNameField"]; XCTAssertTrue(name.waitForExistence(timeout: 3)); name.tap(); name.typeText("UI package")
        app.swipeUp()
        XCTAssertTrue(app.descendants(matching: .any)["packagePriceHelp"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["packageCurrencyPicker"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["packagePaymentStatusPicker"].exists)
        app.buttons["packageSaveButton"].tap()
        XCTAssertTrue(app.staticTexts["UI package"].waitForExistence(timeout: 3))

        app.buttons["packageAddButton"].tap(); app.buttons["Package template"].tap()
        XCTAssertTrue(app.staticTexts["packageTemplateFormIntroduction"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["packageTemplateNameField"].exists)
        XCTAssertTrue(app.textFields["packageTemplateUnitsField"].exists)
        XCTAssertTrue(app.textFields["packageTemplatePriceField"].exists)
        let templateName = app.textFields["packageTemplateNameField"]
        templateName.tap(); templateName.typeText("UI template")
        app.swipeUp()
        XCTAssertTrue(app.buttons["packageTemplateCurrencyPicker"].waitForExistence(timeout: 3))
        app.buttons["packageTemplateSaveButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["packageTemplateRow"].firstMatch.waitForExistence(timeout: 3))
    }
}
