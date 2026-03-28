import XCTest

final class CreateTabUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
        // Ensure we're on the Create tab
        app.tabBars.buttons["Create"].tap()
    }

    func testModeSelector_exists() {
        // The segmented control should exist with Pin, Draw, Template
        XCTAssertTrue(app.buttons["Pin"].exists)
        XCTAssertTrue(app.buttons["Draw"].exists)
        XCTAssertTrue(app.buttons["Template"].exists)
    }

    func testPinMode_showsHint() {
        app.buttons["Pin"].tap()
        XCTAssertTrue(app.staticTexts["Tap the map to place waypoints"].waitForExistence(timeout: 2))
    }

    func testDrawMode_showsHint() {
        app.buttons["Draw"].tap()
        XCTAssertTrue(app.staticTexts["Draw a loop on the map"].waitForExistence(timeout: 2))
    }

    func testTemplateMode_showsShapePicker() {
        app.buttons["Template"].tap()
        XCTAssertTrue(app.buttons["Loop"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Out & Back"].exists)
        XCTAssertTrue(app.buttons["Figure-8"].exists)
    }

    func testTemplateMode_showsGenerateButton() {
        app.buttons["Template"].tap()
        XCTAssertTrue(app.buttons["Generate"].waitForExistence(timeout: 2))
    }

    func testTemplateMode_showsDistanceSlider() {
        app.buttons["Template"].tap()
        XCTAssertTrue(app.sliders.firstMatch.waitForExistence(timeout: 2))
    }

    func testModeSwitching_clearsPins() {
        // Start in Pin mode, switch to Draw, back to Pin - should show hint again
        app.buttons["Pin"].tap()
        // Tap the map to place a pin (center of screen)
        let map = app.maps.firstMatch
        map.tap()
        // Now switch to Draw and back
        app.buttons["Draw"].tap()
        app.buttons["Pin"].tap()
        // Should show the hint again (pins were cleared on mode switch)
        XCTAssertTrue(app.staticTexts["Tap the map to place waypoints"].waitForExistence(timeout: 2))
    }
}
