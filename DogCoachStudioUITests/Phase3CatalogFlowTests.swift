import XCTest

final class Phase3CatalogFlowTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testApprovedPackLoadsAndPrivateExerciseCanBeCreated() {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--phase3-uitesting"]; app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["catalogRoot"].waitForExistence(timeout: 5))
        let publishedExercises = app.descendants(matching: .any).matching(identifier: "catalogPublishedExerciseRow")
        XCTAssertTrue(publishedExercises.firstMatch.waitForExistence(timeout: 3))
        app.buttons["catalogAddMenu"].tap(); app.buttons["Exercise"].tap()
        let title = app.textFields["exerciseTitleField"]; XCTAssertTrue(title.waitForExistence(timeout: 3)); title.tap(); title.typeText("Private UI exercise")
        app.buttons["exerciseSaveButton"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap(); search.typeText("Private UI exercise")
        XCTAssertTrue(app.staticTexts["Private UI exercise"].waitForExistence(timeout: 3))
    }
}
