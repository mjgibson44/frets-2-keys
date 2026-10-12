import XCTest

/// Checks the iPhone landscape layout: one instrument at a time with a Guitar/Piano toggle.
/// Set TEST_RUNNER_SCREENSHOT_DIR to save screenshots of each state.
final class LandscapeTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    private func instrument(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "instrument.\(identifier)").firstMatch
    }

    private func saveScreenshot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }

    func testLandscapeShowsOneInstrumentAtATime() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "Landscape mode is iPhone-only")

        // Portrait: no toggle.
        XCUIDevice.shared.orientation = .portrait
        XCTAssertFalse(app.segmentedControls.buttons["Piano"].exists)

        XCUIDevice.shared.orientation = .landscapeLeft
        let piano = app.segmentedControls.buttons["Piano"]
        let guitar = app.segmentedControls.buttons["Guitar"]
        XCTAssertTrue(piano.waitForExistence(timeout: 5))

        guitar.tap()
        XCTAssertTrue(instrument("Guitar 1").waitForExistence(timeout: 2))
        XCTAssertFalse(instrument("Piano").exists)
        saveScreenshot("landscape-guitar")

        piano.tap()
        XCTAssertTrue(instrument("Piano").waitForExistence(timeout: 2))
        XCTAssertFalse(instrument("Guitar 1").exists)
        saveScreenshot("landscape-piano")

        // Back to portrait: both instruments again.
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(instrument("Guitar 1").waitForExistence(timeout: 5))
        XCTAssertFalse(app.segmentedControls.buttons["Piano"].exists)
    }
}
