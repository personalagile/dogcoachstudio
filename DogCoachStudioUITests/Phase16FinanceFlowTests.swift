import XCTest

final class Phase16FinanceFlowTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testFinanceDashboardAndExportAreAvailable() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--phase16-uitesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["financeRoot"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["financePeriodPicker"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["financeSummary"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["financeRevenueChart"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["financePackageBreakdown"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["financeTransactionsTable"].exists)
        XCTAssertTrue(app.buttons["financeExportButton"].waitForExistence(timeout: 3))
    }
}
