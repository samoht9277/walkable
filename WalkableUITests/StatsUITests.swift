import XCTest

final class StatsUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
        app.tabBars.buttons["Stats"].tap()
    }

    func testPeriodPicker_exists() {
        XCTAssertTrue(app.buttons["Week"].exists || app.buttons["Month"].exists)
    }

    func testPeriodPicker_canSwitch() {
        if app.buttons["Month"].exists {
            app.buttons["Month"].tap()
            // Should still be on stats tab
            XCTAssertTrue(app.buttons["Week"].exists)
        }
    }

    func testStatCards_exist() {
        // The stat cards should show standard labels
        let distance = app.staticTexts["Total Distance"]
        let walks = app.staticTexts["Total Walks"]
        XCTAssertTrue(distance.waitForExistence(timeout: 3) || walks.waitForExistence(timeout: 3))
    }
}
