import XCTest

/// On iPhone the instruments sit between the fixed top bar and chord panel: upright, every
/// instrument that's turned on is stacked on screen at once; sideways, one is on screen at a time
/// and swiping pages between them. Set TEST_RUNNER_SCREENSHOT_DIR to save screenshots.
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
        // Showing means its center is in the band between the top bar and the chord panel.
        let top = app.buttons["Settings"].frame.maxY
        let bottom = app.buttons["Add Chord"].frame.minY
        return app.descendants(matching: .any).matching(identifier: "instrument.\(name)").allElementsBoundByIndex.first { element in
            let frame = element.frame
            return !frame.isEmpty && frame.midY > top && frame.midY < bottom
        }
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

    /// The instruments that are turned on: every one that exists anywhere in the hierarchy.
    private var turnedOnInstruments: [String] {
        ["Guitar 1", "Guitar 2", "Piano"].filter { instrument($0).exists }
    }

    /// Upright, every turned-on instrument is on screen at once, stacked top to bottom between the
    /// bars without overlapping.
    func testUprightStacksEveryInstrument() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "Stacked layout is iPhone-only")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.buttons["Add Chord"].waitForExistence(timeout: 5))

        let expected = turnedOnInstruments
        XCTAssertGreaterThanOrEqual(expected.count, 2, "expected at least two instruments turned on: \(expected)")
        XCTAssertTrue(waitUntil { self.visibleInstruments == expected }, "showing \(visibleInstruments), expected \(expected)")
        assertStackedBetweenBars(expected)
        // The chord panel stays on screen.
        XCTAssertTrue(app.buttons["Add Chord"].isHittable)
        saveScreenshot("phone-portrait")
    }

    /// Sideways, exactly one instrument is on screen at a time, and a guitar's whole neck fits.
    func testSidewaysShowsOneInstrumentAtATime() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "Instrument paging is iPhone-only")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["Add Chord"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntil { self.visibleInstruments.count == 1 }, "\(visibleInstruments)")
        XCTAssertTrue(app.buttons["Add Chord"].isHittable)
        saveScreenshot("phone-landscape")

        // Swipe on the instrument itself: whole-app swipes don't follow the rotation reliably.
        if visibleInstruments.first == "Piano" { onScreen("Piano")?.swipeUp() }
        XCTAssertTrue(waitUntil { self.visibleInstruments.first?.hasPrefix("Guitar") == true }, "\(visibleInstruments)")
        let guitar = try XCTUnwrap(onScreen(visibleInstruments.first ?? "Guitar 1"))
        let screen = app.windows.firstMatch.frame
        XCTAssertTrue(screen.contains(guitar.frame), "fretboard \(guitar.frame) not within \(screen)")
        saveScreenshot("phone-landscape-guitar")

        // Turning back upright stacks them again.
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(waitUntil { self.visibleInstruments.count >= 2 }, "\(visibleInstruments)")
    }

    /// Sideways, swiping on the instrument moves to the next one and back.
    func testSwipingMovesBetweenInstrumentsSideways() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "Instrument paging is iPhone-only")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["Add Chord"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntil { self.visibleInstruments.count == 1 }, "\(visibleInstruments)")
        let first = try XCTUnwrap(visibleInstruments.first)

        try XCTUnwrap(onScreen(first)).swipeUp()
        XCTAssertTrue(waitUntil { self.visibleInstruments.first != first }, "still on \(first)")
        XCTAssertEqual(visibleInstruments.count, 1)

        let second = try XCTUnwrap(visibleInstruments.first)
        try XCTUnwrap(onScreen(second)).swipeDown()
        XCTAssertTrue(waitUntil { self.visibleInstruments.first == first }, "didn't return to \(first)")
    }

    /// Sideways the pages loop: down from the first instrument is the last, and up from the last is
    /// the first.
    func testSwipingWrapsAroundSideways() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "Instrument paging is iPhone-only")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["Add Chord"].waitForExistence(timeout: 5))

        let tabs = app.segmentedControls.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 3))
        tabs.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(waitUntil { self.visibleInstruments.first == "Guitar 1" }, "\(visibleInstruments)")
        let last = try XCTUnwrap(turnedOnInstruments.last)

        try XCTUnwrap(onScreen("Guitar 1")).swipeDown()
        XCTAssertTrue(waitUntil { self.visibleInstruments.first == last }, "\(visibleInstruments)")

        try XCTUnwrap(onScreen(last)).swipeUp()
        XCTAssertTrue(waitUntil { self.visibleInstruments.first == "Guitar 1" }, "\(visibleInstruments)")
    }

    /// Adding chords grows the chord panel; upright, the stacked instruments must all stay between
    /// the bars.
    func testInstrumentsStayBetweenBarsWhenChordPanelGrows() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "Stacked layout is iPhone-only")
        app.terminate()
        app.launchArguments = ["-UITestFreshState"]
        app.launch()
        XCUIDevice.shared.orientation = .portrait

        let addChord = app.buttons["Add Chord"]
        XCTAssertTrue(addChord.waitForExistence(timeout: 5))
        let expected = turnedOnInstruments
        for _ in 0..<5 {
            addChord.tap()
            let add = app.buttons["Add to Set"]
            XCTAssertTrue(add.waitForExistence(timeout: 3))
            add.tap()
            _ = addChord.waitForExistence(timeout: 3)
        }

        XCTAssertTrue(waitUntil { self.visibleInstruments == expected }, "showing \(visibleInstruments), expected \(expected)")
        assertStackedBetweenBars(expected)
        saveScreenshot("phone-panel-grew")
    }

    /// Each instrument lies between the top bar and the chord panel, in order, without overlapping.
    private func assertStackedBetweenBars(_ names: [String], file: StaticString = #filePath, line: UInt = #line) {
        let top = app.buttons["Settings"].frame.maxY
        let bottom = app.buttons["Add Chord"].frame.minY
        var previousMaxY = top
        for name in names {
            guard let element = onScreen(name) else {
                XCTFail("\(name) not on screen", file: file, line: line); return
            }
            let frame = element.frame
            XCTAssertGreaterThanOrEqual(frame.minY, previousMaxY - 1, "\(name) \(frame) overlaps what's above it", file: file, line: line)
            XCTAssertLessThanOrEqual(frame.maxY, bottom + 1, "\(name) \(frame) overlaps the chord panel", file: file, line: line)
            previousMaxY = frame.maxY
        }
    }
}
