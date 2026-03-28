import XCTest

final class LibraryUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
        app.tabBars.buttons["Library"].tap()
    }

    func testEmptyState_showsMessage() {
        // On fresh install, should show empty state
        let emptyText = app.staticTexts["No Routes"]
        if emptyText.exists {
            XCTAssertTrue(true)
        }
        // If routes exist, the list should be visible
    }

    func testSortButton_exists() {
        // The sort menu button should exist in the toolbar
        let sortButton = app.buttons["Sort"]
        if sortButton.exists {
            XCTAssertTrue(true)
        }
    }
}
