import XCTest

/// On iPhone, exactly one instrument is on screen at a time, in either orientation, between the
/// fixed top bar and chord panel. Set TEST_RUNNER_SCREENSHOT_DIR to save screenshots.
final class PhoneLayoutTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    private func instrument(_ name: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "instrument.\(name)").firstMatch
    }

    private var visibleInstruments: [String] {
        ["Guitar 1", "Guitar 2", "Piano"].filter { instrument($0).exists }
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

    func testOneInstrumentAtATimeInBothOrientations() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "One-instrument layout is iPhone-only")

        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            XCUIDevice.shared.orientation = orientation
            _ = app.buttons["Add Chord"].waitForExistence(timeout: 5)
            XCTAssertEqual(visibleInstruments.count, 1, "orientation \(orientation.rawValue): \(visibleInstruments)")
            // The chord panel stays on screen.
            XCTAssertTrue(app.buttons["Add Chord"].isHittable)
            saveScreenshot(orientation == .portrait ? "phone-portrait" : "phone-landscape")
        }
    }
}
