import XCTest

final class Phase2PeopleFlowTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAdaptivePeopleFlowCreatesClientDogIntakeAndGoal() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["appRootTabs"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["peopleAdaptiveNavigation"].exists)

        let suffix = UUID().uuidString.prefix(8)
        let clientName = "UI Client \(suffix)"
        let dogName = "UI Dog \(suffix)"

        addRecord(app: app, menuItem: "New client", fieldID: "clientNameField", value: clientName, saveID: "clientSaveButton")
        XCTAssertTrue(app.descendants(matching: .any)["clientDetail"].waitForExistence(timeout: 3))
        returnToPeopleList(app)

        addRecord(app: app, menuItem: "New dog", fieldID: "dogNameField", value: dogName, saveID: "dogSaveButton")
        XCTAssertTrue(app.descendants(matching: .any)["dogFile"].waitForExistence(timeout: 3))

        let intakeButton = app.buttons["dogIntakeButton"]
        XCTAssertTrue(intakeButton.waitForExistence(timeout: 3))
        intakeButton.tap()
        XCTAssertTrue(app.descendants(matching: .any)["intakeEditor"].waitForExistence(timeout: 3))
        app.textFields["intakeReasonField"].tap()
        app.textFields["intakeReasonField"].typeText("Confidence around visitors")
        app.textViews["intakePrivateNotesField"].tap()
        app.textViews["intakePrivateNotesField"].typeText("PRIVATE UI CANARY")
        app.buttons["intakeSaveButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["dogFile"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["PRIVATE UI CANARY"].exists)

        let goalButton = app.buttons["dogGoalButton"]
        XCTAssertTrue(goalButton.waitForExistence(timeout: 3))
        goalButton.tap()
        let goalField = app.textFields["goalTitleField"]
        XCTAssertTrue(goalField.waitForExistence(timeout: 3))
        goalField.tap()
        goalField.typeText("Calm greeting")
        app.buttons["goalSaveButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["dogFile"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["No goals yet"].exists)
    }

    @MainActor
    private func addRecord(
        app: XCUIApplication,
        menuItem: String,
        fieldID: String,
        value: String,
        saveID: String
    ) {
        let addMenu = app.buttons["peopleAddMenu"]
        XCTAssertTrue(addMenu.waitForExistence(timeout: 3))
        addMenu.tap()
        app.buttons[menuItem].tap()
        let field = app.textFields[fieldID]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText(value)
        app.buttons[saveID].tap()
    }

    @MainActor
    private func returnToPeopleList(_ app: XCUIApplication) {
        let addMenu = app.buttons["peopleAddMenu"]
        if addMenu.exists {
            return
        }

        let backButton = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 3))
        backButton.tap()
        XCTAssertTrue(addMenu.waitForExistence(timeout: 3))
    }
}
