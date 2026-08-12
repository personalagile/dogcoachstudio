import XCTest

final class Phase7PaywallTests: XCTestCase {
    @MainActor
    func testPaywallKeepsRestoreAndDataPromiseVisible() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--phase7-uitesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["paywallRoot"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["restorePurchasesButton"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'readable' OR label CONTAINS[c] 'lesbar'")).firstMatch.exists)
    }
}
