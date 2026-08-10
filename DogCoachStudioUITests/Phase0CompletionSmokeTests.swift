import XCTest

final class Phase0CompletionSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDemoSessionCompletesAndShowsExpectedCounts() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--phase0-demo", "--uitesting"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["sessionCompletionFlow"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["attendanceList"].exists)

        for expectedStep in ["defaultOutcomePicker", "exceptionsList", "completionReview"] {
            app.buttons["continueButton"].tap()
            XCTAssertTrue(app.descendants(matching: .any)[expectedStep].waitForExistence(timeout: 2))
        }

        XCTAssertTrue(app.staticTexts["Exercise results"].exists)
        XCTAssertTrue(app.staticTexts["Package redemptions"].exists)
        XCTAssertTrue(app.staticTexts["Report drafts"].exists)

        app.buttons["completeSessionButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["completionSuccess"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["completedReports"].exists)
        for dogName in ["Luna", "Milo", "Nala", "Balu", "Frieda", "Bruno"] {
            XCTAssertTrue(app.buttons[dogName].exists)
        }
        XCTAssertFalse(app.staticTexts["Private demo note"].exists)
    }
}
