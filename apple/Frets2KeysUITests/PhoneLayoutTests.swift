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

    /// Instruments whose middle is on screen. (Neighboring pages may exist just offscreen.)
    private var visibleInstruments: [String] {
        let screen = app.windows.firstMatch.frame
        return ["Guitar 1", "Guitar 2", "Piano"].filter { name in
            let element = instrument(name)
            guard element.exists else { return false }
            let frame = element.frame
            return screen.contains(CGPoint(x: frame.midX, y: frame.midY))
        }
    }

    /// Polls until `condition` holds or `timeout` passes.
    @discardableResult
    private func waitUntil(timeout: TimeInterval = 3, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return condition()
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

        // Sideways, a guitar's whole neck (all strings and fret numbers) fits without scrolling.
        // Swipe on the instrument itself: whole-app swipes don't follow the rotation reliably.
        if visibleInstruments.first == "Piano" { instrument("Piano").swipeDown() }
        XCTAssertTrue(waitUntil { self.visibleInstruments.first?.hasPrefix("Guitar") == true }, "\(visibleInstruments)")
        let guitar = instrument(visibleInstruments.first ?? "Guitar 1")
        let screen = app.windows.firstMatch.frame
        XCTAssertTrue(screen.contains(guitar.frame), "fretboard \(guitar.frame) not within \(screen)")
        saveScreenshot("phone-landscape-guitar")
    }

    func testSwipingMovesBetweenInstruments() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "Instrument paging is iPhone-only")
        XCUIDevice.shared.orientation = .portrait
        _ = app.buttons["Add Chord"].waitForExistence(timeout: 5)
        let first = try XCTUnwrap(visibleInstruments.first)
        // The piano is the last page, so from there the next instrument is above.
        let startsAtEnd = first == "Piano"
        let towardNext = { startsAtEnd ? self.app.swipeDown() : self.app.swipeUp() }
        let towardFirst = { startsAtEnd ? self.app.swipeUp() : self.app.swipeDown() }

        towardNext()
        XCTAssertTrue(waitUntil { self.visibleInstruments.first != first }, "still on \(first)")
        XCTAssertEqual(visibleInstruments.count, 1)

        towardFirst()
        XCTAssertTrue(waitUntil { self.visibleInstruments.first == first }, "didn't return to \(first)")
    }
}
