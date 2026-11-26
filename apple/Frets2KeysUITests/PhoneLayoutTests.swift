import XCTest

/// On iPhone (portrait only) the instruments that are turned on are stacked between the top bar
/// and the song structure, with the chord bank pinned along the bottom when it's open. Set
/// SCREENSHOT_DIR to save screenshots.
final class PhoneLayoutTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "iPhone layout")
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITestFreshState"]
        app.launch()
    }

    private var menuButton: XCUIElement { app.buttons["View and settings"] }
    private var songPanel: XCUIElement { app.scrollViews["songPanel"] }
    private var chordBank: XCUIElement { app.descendants(matching: .any)["chordBank"] }

    /// The copy of an instrument that's on screen, if any.
    private func onScreen(_ name: String) -> XCUIElement? {
        let element = app.descendants(matching: .any).matching(identifier: "instrument.\(name)").firstMatch
        return element.exists && !element.frame.isEmpty ? element : nil
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

    private func openMenu() {
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5))
        menuButton.tap()
        XCTAssertTrue(app.switches["Song Structure"].waitForExistence(timeout: 3))
    }

    /// Taps outside the popover to close it.
    private func closeMenu() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.95)).tap()
        XCTAssertTrue(waitUntil { !self.app.switches["Song Structure"].exists })
    }

    private func setSwitch(_ name: String, on: Bool) {
        let toggle = app.switches[name]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3), "no \(name) switch")
        if (toggle.value as? String == "1") != on { toggle.switches.firstMatch.tap() }
        XCTAssertTrue(waitUntil { (toggle.value as? String == "1") == on }, "\(name) didn't turn \(on ? "on" : "off")")
    }

    /// Every turned-on instrument is on screen at once, stacked between the bars without overlapping.
    func testStacksEveryInstrument() throws {
        XCTAssertTrue(songPanel.waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntil { self.visibleInstruments.count == 2 }, "\(visibleInstruments)")
        assertStackedBetweenBars(visibleInstruments)
        saveScreenshot("phone-portrait")
    }

    /// The menu has switches for a guitar and the piano, but not a second guitar; turning the
    /// second guitar on in Settings turns the piano off.
    func testInstrumentsAreLimitedToTwo() throws {
        openMenu()
        XCTAssertTrue(app.switches["Guitar"].exists)
        XCTAssertTrue(app.switches["Piano"].exists)
        XCTAssertTrue(app.switches["Chord Bank"].exists)
        XCTAssertFalse(app.switches["Guitar 2"].exists)
        saveScreenshot("phone-menu")

        app.buttons["Settings…"].tap()
        app.buttons["Instruments"].tap()
        setSwitch("Guitar 2", on: true)
        XCTAssertEqual(app.switches["Piano"].value as? String, "0")
        setSwitch("Piano", on: true)
        XCTAssertEqual(app.switches["Guitar 2"].value as? String, "0")
        app.buttons["Done"].tap()
        XCTAssertTrue(waitUntil { self.visibleInstruments == ["Guitar 1", "Piano"] }, "\(visibleInstruments)")
    }

    /// With the chord bank open, a growing song scrolls on its own while the bank stays whole at
    /// the bottom and the instruments keep their place.
    func testChordBankStaysPinnedWhenSongGrows() throws {
        openMenu()
        setSwitch("Chord Bank", on: true)
        closeMenu()
        XCTAssertTrue(chordBank.waitForExistence(timeout: 3))
        let bankHeight = chordBank.frame.height

        for _ in 0..<12 {
            // The bank's own Add (the chord bar above has one too).
            let add = chordBank.buttons["Add to the song"]
            XCTAssertTrue(add.waitForExistence(timeout: 3))
            add.tap()
            let verse = app.buttons["Add to Verse"]
            if verse.waitForExistence(timeout: 1) { verse.tap() }
        }

        let window = app.windows.firstMatch.frame
        XCTAssertEqual(chordBank.frame.height, bankHeight, accuracy: 1, "the chord bank shrank")
        XCTAssertLessThanOrEqual(chordBank.frame.maxY, window.maxY + 1)
        XCTAssertLessThanOrEqual(songPanel.frame.maxY, chordBank.frame.minY + 1)
        XCTAssertTrue(waitUntil { self.visibleInstruments.count == 2 }, "\(visibleInstruments)")
        assertStackedBetweenBars(visibleInstruments)
        saveScreenshot("phone-song-scrolls")
    }

    /// Each instrument lies between the top bar and the song, in order, without overlapping.
    private func assertStackedBetweenBars(_ names: [String], file: StaticString = #filePath, line: UInt = #line) {
        var previousMaxY = menuButton.frame.maxY
        let bottom = songPanel.frame.minY
        for name in names {
            guard let element = onScreen(name) else {
                XCTFail("\(name) not on screen", file: file, line: line); return
            }
            let frame = element.frame
            XCTAssertGreaterThanOrEqual(frame.minY, previousMaxY - 1, "\(name) \(frame) overlaps what's above it", file: file, line: line)
            XCTAssertLessThanOrEqual(frame.maxY, bottom + 1, "\(name) \(frame) overlaps the song", file: file, line: line)
            previousMaxY = frame.maxY
        }
    }
}
