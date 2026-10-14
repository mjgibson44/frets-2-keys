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
        // The bank reopens on whichever tab was used last.
        app.buttons["Chords"].tap()

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

    /// Adds a scale from the Scales tab; it lands in the set and becomes the key.
    func testAddScaleFromScalesTab() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-UITestFreshState"]
        app.launch()
        XCUIDevice.shared.orientation = .portrait

        app.buttons["Add Chord"].tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
        app.buttons["Scales"].tap()
        app.buttons["A"].firstMatch.tap()
        app.buttons["Minor pentatonic"].tap()
        app.buttons["Add to Set"].tap()

        let chip = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "A minor pentatonic scale")).firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Key: A minor pentatonic"].exists)
        if app.buttons["Close"].exists { app.buttons["Close"].tap() }
    }
}
