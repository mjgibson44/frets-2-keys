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

    /// The copy of an instrument that's mostly on screen, if any. (The looping pages repeat each
    /// instrument, and neighboring pages may exist just offscreen.)
    private func onScreen(_ name: String) -> XCUIElement? {
        // Hittable means its center is actually visible, not clipped by the scroll area.
        app.descendants(matching: .any).matching(identifier: "instrument.\(name)").allElementsBoundByIndex.first { $0.isHittable }
    }

    private var visibleInstruments: [String] {
        ["Guitar 1", "Guitar 2", "Piano"].filter { onScreen($0) != nil }
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
            waitUntil { self.visibleInstruments.count == 1 }
            XCTAssertEqual(visibleInstruments.count, 1, "orientation \(orientation.rawValue): \(visibleInstruments)")
            // The chord panel stays on screen.
            XCTAssertTrue(app.buttons["Add Chord"].isHittable)
            saveScreenshot(orientation == .portrait ? "phone-portrait" : "phone-landscape")
        }

        // Sideways, a guitar's whole neck (all strings and fret numbers) fits without scrolling.
        // Swipe on the instrument itself: whole-app swipes don't follow the rotation reliably.
        if visibleInstruments.first == "Piano" { onScreen("Piano")?.swipeUp() }
        XCTAssertTrue(waitUntil { self.visibleInstruments.first?.hasPrefix("Guitar") == true }, "\(visibleInstruments)")
        let guitar = try XCTUnwrap(onScreen(visibleInstruments.first ?? "Guitar 1"))
        let screen = app.windows.firstMatch.frame
        XCTAssertTrue(screen.contains(guitar.frame), "fretboard \(guitar.frame) not within \(screen)")
        saveScreenshot("phone-landscape-guitar")
    }

    func testSwipingMovesBetweenInstruments() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "Instrument paging is iPhone-only")
        XCUIDevice.shared.orientation = .portrait
        _ = app.buttons["Add Chord"].waitForExistence(timeout: 5)
        let first = try XCTUnwrap(visibleInstruments.first)

        app.swipeUp()
        XCTAssertTrue(waitUntil { self.visibleInstruments.first != first }, "still on \(first)")
        XCTAssertEqual(visibleInstruments.count, 1)

        app.swipeDown()
        XCTAssertTrue(waitUntil { self.visibleInstruments.first == first }, "didn't return to \(first)")
    }

    /// The pages loop: up from the first instrument is the last, and down from the last is the first.
    func testSwipingWrapsAround() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "Instrument paging is iPhone-only")
        XCUIDevice.shared.orientation = .portrait
        _ = app.buttons["Add Chord"].waitForExistence(timeout: 5)

        let tabs = app.segmentedControls.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 3))
        let firstTab = tabs.buttons.element(boundBy: 0)
        firstTab.tap()
        XCTAssertTrue(waitUntil { self.visibleInstruments.first == "Guitar 1" }, "\(visibleInstruments)")

        // Swiping down from the first instrument wraps to the last (the piano).
        app.swipeDown()
        XCTAssertTrue(waitUntil { self.visibleInstruments.first == "Piano" }, "\(visibleInstruments)")

        // And up from the piano wraps back to the first.
        app.swipeUp()
        XCTAssertTrue(waitUntil { self.visibleInstruments.first == "Guitar 1" }, "\(visibleInstruments)")
    }

    /// Adding chords grows the chord panel; the instrument must stay snapped between the bars.
    func testInstrumentStaysCenteredWhenChordPanelGrows() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "Instrument paging is iPhone-only")
        app.terminate()
        app.launchArguments = ["-UITestFreshState"]
        app.launch()
        XCUIDevice.shared.orientation = .portrait

        let addChord = app.buttons["Add Chord"]
        XCTAssertTrue(addChord.waitForExistence(timeout: 5))
        for _ in 0..<5 {
            addChord.tap()
            let add = app.buttons["Add to Set"]
            XCTAssertTrue(add.waitForExistence(timeout: 3))
            add.tap()
            _ = addChord.waitForExistence(timeout: 3)
        }

        let tabs = app.segmentedControls.firstMatch
        XCTAssertTrue(waitUntil { self.visibleInstruments.count == 1 }, "\(visibleInstruments)")
        let shown = try XCTUnwrap(onScreen(visibleInstruments[0]))
        XCTAssertGreaterThanOrEqual(shown.frame.minY, tabs.frame.maxY, "instrument overlaps the top bar")
        XCTAssertLessThanOrEqual(shown.frame.maxY, addChord.frame.minY, "instrument overlaps the chord panel")
        saveScreenshot("phone-panel-grew")
    }
}
