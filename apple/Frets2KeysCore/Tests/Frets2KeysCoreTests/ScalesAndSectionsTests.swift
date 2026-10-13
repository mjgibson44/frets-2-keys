import XCTest
@testable import Frets2KeysCore

final class ScaleTypeTests: XCTestCase {
    func testDegreesAreSpelledAgainstMajor() {
        XCTAssertEqual(MusicalKey(root: 9, type: .minor).degreeLabels, ["1", "2", "♭3", "4", "5", "♭6", "♭7"])
        XCTAssertEqual(MusicalKey(root: 0, type: .blues).degreeLabels, ["1", "♭3", "4", "♭5", "5", "♭7"])
        XCTAssertEqual(MusicalKey(root: 0, type: .lydian).degreeLabels, ["1", "2", "3", "♯4", "5", "6", "7"])
    }

    func testIntervalsMatchDegrees() {
        XCTAssertEqual(ScaleType.major.intervals, [0, 2, 4, 5, 7, 9, 11])
        XCTAssertEqual(ScaleType.minor.intervals, [0, 2, 3, 5, 7, 8, 10])
        XCTAssertEqual(ScaleType.minorPentatonic.intervals, [0, 3, 5, 7, 10])
        XCTAssertEqual(ScaleType.diminishedWholeHalf.intervals, [0, 2, 3, 5, 6, 8, 9, 11])
        for type in ScaleType.allCases {
            XCTAssertEqual(Set(type.intervals).count, type.intervals.count, type.name)
            XCTAssertEqual(type.intervals, type.intervals.sorted(), type.name)
        }
    }

    func testDegreeOfNotesInAndOutOfTheScale() {
        let c = MusicalKey.cMajor
        XCTAssertEqual(c.degree(of: "E4").label, "3")
        XCTAssertEqual(c.degree(of: "F#4").label, "♯4")
        XCTAssertEqual(c.degree(of: "Bb4").label, "♭7")
        let aMinor = MusicalKey(root: 9, type: .minor)
        XCTAssertEqual(aMinor.degree(of: "C4").label, "♭3")
        // C# in A minor is a major third, not a sharpened ♭3.
        XCTAssertEqual(aMinor.degree(of: "C#4").label, "3")
        XCTAssertEqual(MusicalKey(root: 0, type: .blues).degree(of: "F#4").label, "♭5")
    }

    func testModesBorrowTheirParentKeysSpelling() {
        XCTAssertEqual(MusicalKey(root: 2, type: .dorian).noteNames(), ["D", "E", "F", "G", "A", "B", "C"])
        XCTAssertTrue(MusicalKey(root: 0, type: .mixolydian).usesFlats)
        XCTAssertEqual(MusicalKey(root: 0, type: .mixolydian).noteNames().last, "Bb")
        XCTAssertEqual(MusicalKey(root: 4, type: .phrygian).noteNames(), ["E", "F", "G", "A", "B", "C", "D"])
        XCTAssertEqual(MusicalKey(root: 9, type: .minorPentatonic).name(), "A minor pentatonic")
        XCTAssertEqual(MusicalKey(root: 9, type: .minorPentatonic).shortName(), "Am pent.")
        XCTAssertEqual(MusicalKey(root: 2, type: .dorian).shortName(), "D Dorian")
        XCTAssertEqual(MusicalKey(root: 10, type: .major).shortName(), "Bb major")
    }

    func testColorsFollowDegreeNumbers() {
        let pentatonic = MusicalKey(root: 9, type: .minorPentatonic)
        // C is ♭3 → the "3" color.
        XCTAssertEqual(NoteAppearance.colorRole(for: "C4", key: pentatonic), .scaleDegree(2))
        XCTAssertEqual(NoteAppearance.colorRole(for: "G4", key: pentatonic), .scaleDegree(6))
        // Seven notes are outside a pentatonic scale.
        XCTAssertEqual(NoteAppearance.colorRole(for: "G#4", key: pentatonic), .outOfKey(6))
    }

    func testDiatonicChordsForOtherScales() {
        let dorian = MusicalKey(root: 2, type: .dorian)
        XCTAssertEqual(dorian.diatonicChords().map(\.numeral), ["i", "ii", "♭III", "IV", "v", "vi°", "♭VII"])
        let harmonic = MusicalKey(root: 9, type: .harmonicMinor)
        XCTAssertEqual(harmonic.diatonicChords().count, 7)
        XCTAssertEqual(harmonic.diatonicChords()[2].numeral, "♭III+")
        XCTAssertEqual(harmonic.diatonicChords(sevenths: true).count, 7)
        XCTAssertTrue(MusicalKey(root: 0, type: .majorPentatonic).diatonicChords().isEmpty)
    }

    func testOldKeysStillDecode() throws {
        let key = try JSONDecoder().decode(MusicalKey.self, from: Data(#"{"root":9,"type":"minor"}"#.utf8))
        XCTAssertEqual(key, MusicalKey(root: 9, type: .minor))
    }

    func testAscendingNotes() {
        let notes = MusicalKey(root: 9, type: .minorPentatonic).ascendingNotes
        XCTAssertEqual(notes.map(\.description), ["A3", "C4", "D4", "E4", "G4", "A4"])
    }
}

final class NoteLabelTests: XCTestCase {
    private func label(_ note: Note, _ context: NoteLabelContext) -> String {
        NoteAppearance(note: note, isSelected: false, context: context).label
    }

    func testDegrees() {
        let context = NoteLabelContext(key: MusicalKey(root: 7, type: .major), content: .degrees)
        XCTAssertEqual(label("G3", context), "1")
        XCTAssertEqual(label("F#3", context), "7")
        XCTAssertEqual(label("F3", context), "♭7")
    }

    func testDegreesWithoutAKeyFallBackToNames() {
        let context = NoteLabelContext(key: nil, content: .degrees)
        XCTAssertEqual(label("F#3", context), "F#")
    }

    func testIntervals() {
        var state = AppState()
        state.noteLabelContent = .intervals
        state.select(notes: ["A3", "C4", "E4", "G4"]) // Am7
        let context = state.noteLabelContext
        XCTAssertEqual(label("A5", context), "R")
        XCTAssertEqual(label("C2", context), "♭3")
        XCTAssertEqual(label("E4", context), "5")
        XCTAssertEqual(label("G4", context), "♭7")
        XCTAssertEqual(label("B4", context), "9")
        XCTAssertEqual(label("D4", context), "11")
    }

    func testIntervalsSpellToSuitTheChord() {
        XCTAssertEqual(IntervalSpeller(root: 0, chord: ["C4", "E4", "G#4"]).label(for: "G#4"), "♯5")
        XCTAssertEqual(IntervalSpeller(root: 0, chord: ["C4", "E4", "G4"]).label(for: "Ab4"), "♭6")
        XCTAssertEqual(IntervalSpeller(root: 0, chord: ["C4", "Eb4", "Gb4", "A4"]).label(for: "A4"), "𝄫7")
        XCTAssertEqual(IntervalSpeller(root: 0, chord: ["C4", "D4", "G4"]).label(for: "D4"), "2")
        XCTAssertEqual(IntervalSpeller(root: 0, chord: ["C4", "E4", "G4", "Bb4", "D#5"]).label(for: "D#5"), "♯9")
        // A plain triad doesn't use extensions.
        let triad = IntervalSpeller(root: 0, chord: ["C4", "E4", "G4"])
        XCTAssertEqual(["Db4", "D4", "Eb4", "F4", "A4"].map { triad.label(for: Note(parsing: $0)!) }, ["♭2", "2", "♭3", "4", "6"])
        XCTAssertEqual(IntervalSpeller(root: 0, chord: ["C4", "E4", "G4", "D5"]).label(for: "D5"), "9")
    }

    func testIntervalsWithoutASelectionFallBackToNames() {
        var state = AppState()
        state.noteLabelContent = .intervals
        XCTAssertEqual(label("E4", state.noteLabelContext), "E")
    }

    func testIntervalsUseTheChordRootNotTheBass() {
        var state = AppState()
        state.noteLabelContent = .intervals
        state.select(notes: ["E3", "G3", "C4"]) // Cmaj/E
        XCTAssertEqual(state.chordRootPitchClass, 0)
        XCTAssertEqual(label("E3", state.noteLabelContext), "3")
    }

    func testLabelContentPersistsAndDefaultsToNames() throws {
        var state = AppState()
        state.noteLabelContent = .degrees
        let decoded = try JSONDecoder().decode(AppState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded.noteLabelContent, .degrees)
        let old = try JSONDecoder().decode(AppState.self, from: Data("{}".utf8))
        XCTAssertEqual(old.noteLabelContent, .names)
    }

    func testCycling() {
        XCTAssertEqual(NoteLabelContent.names.next, .degrees)
        XCTAssertEqual(NoteLabelContent.intervals.next, .names)
    }
}

final class SavedScaleTests: XCTestCase {
    func testAddingAScaleShowsIt() {
        var state = AppState()
        let blues = MusicalKey(root: 4, type: .blues)
        XCTAssertEqual(state.addScale(blues), .saved)
        XCTAssertEqual(state.selectedKey, blues)
        XCTAssertEqual(state.savedChords.first?.name, "E blues")
        XCTAssertTrue(state.savedChords[0].isScale)
        XCTAssertEqual(state.savedChords[0].rootPitchClass, 4)
    }

    func testSelectingAScaleKeepsTheChord() {
        var state = AppState()
        state.addChord(notes: ["A3", "C4", "E4"])
        let chordID = state.activeChordID
        state.addScale(MusicalKey(root: 9, type: .minorPentatonic))
        state.selectedKey = .cMajor
        state.selectChord(id: state.savedChords[1].id)
        XCTAssertEqual(state.selectedKey, MusicalKey(root: 9, type: .minorPentatonic))
        XCTAssertEqual(state.selectedNotes, ["A3", "C4", "E4"])
        XCTAssertEqual(state.activeChordID, chordID)
    }

    func testLoopAndArrowsSkipScales() {
        var state = AppState()
        state.addChord(notes: ["C4", "E4", "G4"])
        state.addScale(.cMajor)
        state.addChord(notes: ["F4", "A4", "C5"])
        XCTAssertEqual(state.chordsOnly.map(\.name), ["Cmaj", "Fmaj"])
        state.selectNextChord()
        XCTAssertEqual(state.chordName, "Cmaj")
        state.selectNextChord()
        XCTAssertEqual(state.chordName, "Fmaj")

        var sequencer = LoopSequencer(startingFrom: state)
        var played: [String] = []
        for _ in 0..<8 {
            _ = sequencer.nextBeat(&state)
            played.append(state.chordName ?? "")
        }
        XCTAssertEqual(Set(played), ["Cmaj", "Fmaj"])
    }

    func testLoneChordLoopsWithNothingSelected() {
        var state = AppState()
        state.addChord(notes: ["G3", "B3", "D4", "F4"])
        state.clearSelection()
        var sequencer = LoopSequencer(startingFrom: state)
        XCTAssertEqual(sequencer.nextBeat(&state), ["G3", "B3", "D4", "F4"])
        XCTAssertEqual(state.chordName, "G7")
    }

    func testOnlyScalesCantLoop() {
        var state = AppState()
        state.addScale(.cMajor)
        XCTAssertFalse(state.canLoop)
    }

    func testScaleRoundTrip() throws {
        var state = AppState()
        state.addScale(MusicalKey(root: 2, type: .dorian))
        let decoded = try JSONDecoder().decode(AppState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded.savedChords, state.savedChords)
    }
}

final class SectionTests: XCTestCase {
    private func names(_ state: AppState) -> [[String]] {
        state.activeSet.sections.map { $0.chords.map(\.name) }
    }

    /// A set with sections "Verse" [Cmaj, Fmaj] and "Chorus" [Gmaj, Am].
    private func song() -> (AppState, verse: UUID, chorus: UUID) {
        var state = AppState()
        let verse = state.activeSet.sections[0].id
        state.renameSection(id: verse, to: "Verse")
        state.addChord(notes: ["C4", "E4", "G4"])
        state.addChord(notes: ["F4", "A4", "C5"])
        let chorus = state.addSection(named: "Chorus")
        state.addChord(notes: ["G3", "B3", "D4"], to: chorus)
        state.addChord(notes: ["A3", "C4", "E4"], to: chorus)
        return (state, verse, chorus)
    }

    func testNewSetsHaveOneUnnamedSection() {
        let state = AppState()
        XCTAssertEqual(state.activeSet.sections.count, 1)
        XCTAssertEqual(state.activeSet.sections[0].name, "")
        XCTAssertEqual(state.activeSet.sections[0].displayName(index: 0), "Section 1")
    }

    func testAddingSectionsNamesThem() {
        var state = AppState()
        state.addSection()
        XCTAssertEqual(state.activeSet.sections.map(\.name), ["Section 1", "Section 2"])
    }

    func testChordsGoToTheActiveSection() {
        var (state, _, chorus) = song()
        XCTAssertEqual(names(state), [["Cmaj", "Fmaj"], ["Gmaj", "Am"]])
        // The active chord (Am) is in the chorus, so a new chord goes there.
        XCTAssertEqual(state.activeSectionID, chorus)
        state.select(notes: ["E4", "G#4", "B4"])
        state.saveAsNewChord()
        XCTAssertEqual(names(state), [["Cmaj", "Fmaj"], ["Gmaj", "Am", "Emaj"]])
        // Selecting a verse chord makes the verse active.
        state.selectChord(id: state.savedChords[0].id)
        XCTAssertNotEqual(state.activeSectionID, chorus)
    }

    func testMovingChordsBetweenSections() {
        var (state, verse, chorus) = song()
        let am = state.savedChords[3].id
        state.moveChord(id: am, to: state.savedChords[0].id)
        XCTAssertEqual(names(state), [["Am", "Cmaj", "Fmaj"], ["Gmaj"]])
        state.moveChord(id: am, toSection: chorus)
        XCTAssertEqual(names(state), [["Cmaj", "Fmaj"], ["Gmaj", "Am"]])
        // Shifting past the end of a section moves into the next one.
        let fmaj = state.savedChords[1].id
        state.shiftChord(id: fmaj, by: 1)
        XCTAssertEqual(names(state), [["Cmaj"], ["Fmaj", "Gmaj", "Am"]])
        state.shiftChord(id: fmaj, by: -1)
        XCTAssertEqual(names(state), [["Cmaj", "Fmaj"], ["Gmaj", "Am"]])
        XCTAssertFalse(state.canShiftChord(id: state.savedChords[0].id, by: -1))
        XCTAssertFalse(state.canShiftChord(id: state.savedChords[3].id, by: 1))
        // A section can be emptied.
        state.moveChord(id: state.savedChords[0].id, toSection: chorus)
        state.moveChord(id: state.savedChords[0].id, toSection: chorus)
        XCTAssertEqual(names(state), [[], ["Gmaj", "Am", "Cmaj", "Fmaj"]])
        XCTAssertEqual(state.activeSet.sections[0].id, verse)
    }

    func testReorderingRenamingAndDeletingSections() {
        var (state, verse, chorus) = song()
        state.moveSection(id: chorus, to: verse)
        XCTAssertEqual(state.activeSet.sections.map(\.name), ["Chorus", "Verse"])
        state.shiftSection(id: chorus, by: 1)
        XCTAssertEqual(state.activeSet.sections.map(\.name), ["Verse", "Chorus"])
        state.renameSection(id: chorus, to: "  ")
        XCTAssertEqual(state.activeSet.sections[1].name, "Chorus")
        state.renameSection(id: chorus, to: "Bridge")
        XCTAssertEqual(state.activeSet.sections[1].name, "Bridge")

        state.deleteSection(id: chorus)
        XCTAssertEqual(names(state), [["Cmaj", "Fmaj"]])
        XCTAssertNil(state.activeChordID, "the active chord was in the deleted section")
        state.deleteSection(id: verse)
        XCTAssertEqual(state.activeSet.sections.count, 1, "the last section stays")
    }

    func testSectionEditsMarkTheSetModified() {
        var state = AppState()
        let before = state.activeSet.modifiedAt
        Thread.sleep(forTimeInterval: 0.01)
        state.addSection()
        XCTAssertGreaterThan(state.activeSet.modifiedAt, before)
    }

    func testLoopWalksEverySectionOrJustOne() {
        var (state, _, chorus) = song()
        var whole = LoopSequencer(startingFrom: state)
        var played: [String] = []
        for _ in 0..<(4 * LoopSequencer.repeatsPerChord) {
            _ = whole.nextBeat(&state)
            if played.last != state.chordName { played.append(state.chordName ?? "") }
        }
        // Starts from the active chord (Am), then wraps through the verse.
        XCTAssertEqual(played, ["Am", "Cmaj", "Fmaj", "Gmaj"])

        state.selectChord(id: state.savedChords[0].id)
        var section = LoopSequencer(startingFrom: state, sectionID: chorus)
        played = []
        for _ in 0..<(3 * LoopSequencer.repeatsPerChord) {
            _ = section.nextBeat(&state)
            if played.last != state.chordName { played.append(state.chordName ?? "") }
        }
        XCTAssertEqual(played, ["Gmaj", "Am", "Gmaj"])
    }

    func testDuplicateCopiesSections() {
        var (state, _, _) = song()
        let original = state.activeSet
        state.duplicateSet(id: original.id)
        XCTAssertEqual(state.activeSet.sections.map(\.name), original.sections.map(\.name))
        XCTAssertEqual(names(state), [["Cmaj", "Fmaj"], ["Gmaj", "Am"]])
        XCTAssertNotEqual(state.activeSet.sections[0].id, original.sections[0].id)
        XCTAssertNotEqual(state.savedChords[0].id, original.chords[0].id)
    }

    func testSetsWithoutSectionsDecodeAsOne() throws {
        let id = UUID()
        let json = """
        {"id":"\(id.uuidString)","name":"Old","createdAt":0,"modifiedAt":0,
         "chords":[{"id":"\(UUID().uuidString)","name":"Cmaj","notes":[{"midi":60},{"midi":64},{"midi":67}]}]}
        """
        let set = try JSONDecoder().decode(ChordSet.self, from: Data(json.utf8))
        XCTAssertEqual(set.sections.count, 1)
        XCTAssertEqual(set.chords.map(\.name), ["Cmaj"])
    }

    func testSetsStillWriteAFlatChordList() throws {
        let (state, _, _) = song()
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state.activeSet)) as? [String: Any]
        XCTAssertEqual((object?["chords"] as? [Any])?.count, 4)
        XCTAssertEqual((object?["sections"] as? [Any])?.count, 2)
    }

    func testSyncKeepsSections() {
        let (phone, _, _) = song()
        var mac = AppState()
        mac.apply(ChordLibrary.mergeIncoming(local: mac.chordLibrary, remote: phone.chordLibrary))
        XCTAssertEqual(mac.activeSet.sections.map(\.name), ["Verse", "Chorus"])
    }
}
