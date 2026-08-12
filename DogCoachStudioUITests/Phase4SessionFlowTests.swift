import XCTest

final class Phase4SessionFlowTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testSessionPreviewCompletionAndCorrection() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--phase4-uitesting"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["sessionsRoot"].waitForExistence(timeout: 5))
        let row = app.buttons["scheduledSessionRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3)); row.tap()
        XCTAssertTrue(app.descendants(matching: .any)["sessionCompletionReview"].waitForExistence(timeout: 3))
        app.buttons["completionPreviewButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["completionPreview"].waitForExistence(timeout: 3))
        app.buttons["persistentCompleteButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["persistentCompletionSuccess"].waitForExistence(timeout: 3))
        app.buttons["correctionButton"].tap()
        let reason = app.textFields["correctionReasonField"]
        XCTAssertTrue(reason.waitForExistence(timeout: 3)); reason.tap(); reason.typeText("UI correction")
        app.buttons["correctionSaveButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["completionRevision-2"].waitForExistence(timeout: 3))
    }
}
