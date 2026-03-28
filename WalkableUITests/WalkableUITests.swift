import XCTest

final class WalkableUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func testAppLaunches() {
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }

    func testAllTabsExist() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Create"].exists)
        XCTAssertTrue(tabBar.buttons["Library"].exists)
        XCTAssertTrue(tabBar.buttons["Walk"].exists)
        XCTAssertTrue(tabBar.buttons["Stats"].exists)
    }

    func testSwitchToLibraryTab() {
        app.tabBars.buttons["Library"].tap()
        // Library should show either routes or empty state
        let noRoutes = app.staticTexts["No Routes"]
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(noRoutes.exists || searchField.exists)
    }

    func testSwitchToWalkTab() {
        app.tabBars.buttons["Walk"].tap()
        XCTAssertTrue(app.staticTexts["No Active Walk"].exists)
    }

    func testSwitchToStatsTab() {
        app.tabBars.buttons["Stats"].tap()
        // Stats should show period picker
        XCTAssertTrue(app.buttons["Week"].exists || app.buttons["Month"].exists)
    }
}
