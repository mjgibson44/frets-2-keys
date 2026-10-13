import XCTest

/// Opens the chord bank side panel, adds a chord, and checks it lands in the active set.
/// Set TEST_RUNNER_SCREENSHOT_DIR to save a screenshot of the open panel.
final class ChordBankTests: XCTestCase {
    func testAddChordFromSidePanel() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        XCUIDevice.shared.orientation = .portrait

        app.buttons["Add Chord"].tap()
        let close = app.buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))

        app.buttons["G"].firstMatch.tap()
        app.buttons["7"].firstMatch.tap()
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            let name = UIDevice.current.userInterfaceIdiom == .pad ? "chord-bank-ipad" : "chord-bank-iphone"
            try? XCUIScreen.main.screenshot().pngRepresentation
                .write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
        app.buttons["Add to Set"].tap()

        // The new chord appears in the chord panel.
        XCTAssertTrue(app.buttons["G7"].waitForExistence(timeout: 3) || app.staticTexts["G7"].waitForExistence(timeout: 1))
        if close.exists { close.tap() }
    }
}
