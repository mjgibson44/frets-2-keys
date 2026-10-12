import XCTest
@testable import Frets2KeysCore

final class NoteTests: XCTestCase {
    func testParsing() {
        XCTAssertEqual(Note(parsing: "C4")?.midi, 60)
        XCTAssertEqual(Note(parsing: "A4")?.midi, 69)
        XCTAssertEqual(Note(parsing: "E2")?.midi, 40)
        XCTAssertEqual(Note(parsing: "F#1")?.midi, 30)
        XCTAssertEqual(Note(parsing: "B0")?.midi, 23)
        XCTAssertEqual(Note(parsing: "bb3"), Note(parsing: "A#3"))
        XCTAssertEqual(Note(parsing: " g4 ")?.description, "G4")
        XCTAssertNil(Note(parsing: "H2"))
        XCTAssertNil(Note(parsing: "C"))
        XCTAssertNil(Note(parsing: "C#x"))
        XCTAssertNil(Note(parsing: ""))
    }

    func testDescription() {
        XCTAssertEqual(Note(midi: 61).description, "C#4")
        XCTAssertEqual(Note(midi: 23).description, "B0")
        XCTAssertEqual(Note(midi: 0).description, "C-1")
    }

    func testFrequency() {
        XCTAssertEqual(Note(parsing: "A4")!.frequency, 440, accuracy: 0.001)
        XCTAssertEqual(Note(parsing: "A5")!.frequency, 880, accuracy: 0.001)
    }

    func testBlackKeys() {
        XCTAssertTrue(Note(parsing: "C#4")!.isBlackKey)
        XCTAssertFalse(Note(parsing: "E4")!.isBlackKey)
    }
}

final class KeyTests: XCTestCase {
    func testFlatKeys() {
        let fMajor = MusicalKey(root: 5, type: .major)
        XCTAssertTrue(fMajor.usesFlats)
        XCTAssertEqual(fMajor.noteNames(), ["F", "G", "A", "Bb", "C", "D", "E"])
        XCTAssertEqual(fMajor.noteNames(sharpsOnly: true), ["F", "G", "A", "A#", "C", "D", "E"])
        XCTAssertEqual(MusicalKey(root: 10, type: .major).name(), "Bb major")
        XCTAssertEqual(MusicalKey(root: 10, type: .major).name(sharpsOnly: true), "A# major")
        XCTAssertEqual(MusicalKey(root: 2, type: .minor).name(), "D minor")
        XCTAssertTrue(MusicalKey(root: 2, type: .minor).usesFlats)
        XCTAssertFalse(MusicalKey(root: 7, type: .major).usesFlats)
        XCTAssertEqual(MusicalKey(root: 6, type: .major).name(), "Gb major")
    }

    func testScaleDegrees() {
        let c = MusicalKey.cMajor
        XCTAssertEqual(c.scaleDegree(of: "C4"), 0)
        XCTAssertEqual(c.scaleDegree(of: "B2"), 6)
        XCTAssertNil(c.scaleDegree(of: "C#4"))
        XCTAssertEqual(c.chromaticIndex(of: "C#4"), 0)
        XCTAssertEqual(c.chromaticIndex(of: "A#4"), 4)
        XCTAssertNil(c.chromaticIndex(of: "D4"))
        let aMinor = MusicalKey(root: 9, type: .minor)
        XCTAssertEqual(aMinor.noteNames(), ["A", "B", "C", "D", "E", "F", "G"])
    }

    func testDisplayName() {
        let fMajor = MusicalKey(root: 5, type: .major)
        XCTAssertEqual(displayName(for: "A#3", key: fMajor, sharpsOnly: false), "Bb")
        XCTAssertEqual(displayName(for: "A#3", key: fMajor, sharpsOnly: true), "A#")
        XCTAssertEqual(displayName(for: "A#3", key: nil, sharpsOnly: false), "A#")
        XCTAssertEqual(displayName(for: "C#3", key: .cMajor, sharpsOnly: false), "C#")
        XCTAssertTrue(splitNoteDisplay("Bb") == ("B", "b"))
        XCTAssertTrue(splitNoteDisplay("C") == ("C", nil))
    }

    func testAllKeys() {
        XCTAssertEqual(MusicalKey.all.count, 24)
        XCTAssertEqual(Set(MusicalKey.all.map(\.id)).count, 24)
    }
}

final class ChordTests: XCTestCase {
    private func identify(_ notes: String...) -> String? {
        ChordIdentifier.identify(notes.map { Note(parsing: $0)! })
    }

    func testBasics() {
        XCTAssertNil(identify())
        XCTAssertEqual(identify("C#4"), "C#")
        XCTAssertEqual(identify("C3", "C4"), "C")
    }

    func testTriads() {
        XCTAssertEqual(identify("C4", "E4", "G4"), "Cmaj")
        XCTAssertEqual(identify("A3", "C4", "E4"), "Am")
        XCTAssertEqual(identify("B3", "D4", "F4"), "Bdim")
        XCTAssertEqual(identify("C4", "E4", "G#4"), "Caug")
        XCTAssertEqual(identify("D4", "G4", "A4"), "Dsus4")
    }

    func testInversionsAndSevenths() {
        XCTAssertEqual(identify("E3", "G3", "C4"), "Cmaj/E")
        XCTAssertEqual(identify("G3", "B3", "D4", "F4"), "G7")
        XCTAssertEqual(identify("C4", "E4", "G4", "B4"), "Cmaj7")
        XCTAssertEqual(identify("G3", "A3", "C4", "E4"), "Am7/G")
    }

    func testOpenChordsFromGuitar() {
        // Open E major: E2 B2 E3 G#3 B3 E4
        XCTAssertEqual(identify("E2", "B2", "E3", "G#3", "B3", "E4"), "Emaj")
        // Open G: G2 B2 D3 G3 B3 G4
        XCTAssertEqual(identify("G2", "B2", "D3", "G3", "B3", "G4"), "Gmaj")
    }

    func testIntervalsAndPower() {
        XCTAssertEqual(identify("C4", "G4"), "C5")
        XCTAssertEqual(identify("C4", "D4"), "C (maj 2nd)")
        XCTAssertEqual(identify("C4", "F#4"), "C (tritone)")
    }

    func testSubsetMatch() {
        // C major plus an F# → matched as a known chord with extra notes, or something reasonable.
        let name = identify("C4", "D4", "E4", "F#4", "G4")
        XCTAssertNotNil(name)
        XCTAssertTrue(name!.contains("*") || !name!.contains("unrecognized"))
    }

    func testUnrecognized() {
        XCTAssertEqual(identify("C4", "C#4", "D4"), "C (unrecognized)")
    }
}

final class AppearanceTests: XCTestCase {
    func testSelectedInKey() {
        let a = NoteAppearance(note: "E4", isSelected: true, key: .cMajor, keyLabelMode: .showAll, noteLabelMode: .sharpsAndFlats)
        XCTAssertEqual(a.style, .selected(.scaleDegree(2)))
        XCTAssertTrue(a.showsLabel)
        XCTAssertFalse(a.isDimmed)
    }

    func testSelectedOutOfKeyAndNoKey() {
        let outOfKey = NoteAppearance(note: "F#4", isSelected: true, key: .cMajor, keyLabelMode: .showAll, noteLabelMode: .sharpsAndFlats)
        XCTAssertEqual(outOfKey.style, .selected(.outOfKey(2)))
        let noKey = NoteAppearance(note: "F#4", isSelected: true, key: nil, keyLabelMode: .showAll, noteLabelMode: .sharpsAndFlats)
        XCTAssertEqual(noKey.style, .selected(.chromatic(6)))
    }

    func testUnselectedModes() {
        let dimmed = NoteAppearance(note: "F#4", isSelected: false, key: .cMajor, keyLabelMode: .showAll, noteLabelMode: .sharpsAndFlats)
        XCTAssertEqual(dimmed.style, .plain)
        XCTAssertTrue(dimmed.isDimmed)
        XCTAssertTrue(dimmed.showsLabel)

        let hidden = NoteAppearance(note: "F#4", isSelected: false, key: .cMajor, keyLabelMode: .onlyInKey, noteLabelMode: .sharpsAndFlats)
        XCTAssertFalse(hidden.showsLabel)

        let inKey = NoteAppearance(note: "G4", isSelected: false, key: .cMajor, keyLabelMode: .onlyInKey, noteLabelMode: .sharpsAndFlats)
        XCTAssertEqual(inKey.style, .inKey(scaleDegree: 4))
        XCTAssertTrue(inKey.showsLabel)

        let noKey = NoteAppearance(note: "F#4", isSelected: false, key: nil, keyLabelMode: .onlyInKey, noteLabelMode: .sharpsAndFlats)
        XCTAssertEqual(noKey.style, .plain)
        XCTAssertTrue(noKey.showsLabel)
        XCTAssertFalse(noKey.isDimmed)
    }
}

final class AppStateTests: XCTestCase {
    func testToggleAndClear() {
        var state = AppState()
        XCTAssertTrue(state.toggle("C4"))
        XCTAssertTrue(state.toggle("E4"))
        XCTAssertFalse(state.toggle("C4"))
        XCTAssertEqual(state.selectedNotes, ["E4"])
        state.clearSelection()
        XCTAssertTrue(state.selectedNotes.isEmpty)
    }

    func testTranspose() {
        var state = AppState()
        state.keyLabelMode = .onlyInKey
        state.toggle("C4"); state.toggle("E4"); state.toggle("G4")
        state.transpose(by: 2)
        XCTAssertEqual(state.selectedNotes, ["D4", "F#4", "A4"])
        XCTAssertEqual(state.chordName, "Dmaj")
        XCTAssertEqual(state.keyLabelMode, .showAll)
        state.selectedNotes = [Note(midi: 127)]
        state.transpose(by: 1)
        XCTAssertEqual(state.selectedNotes, [Note(midi: 127)])
    }

    func testSaveUpdateSelectDelete() {
        var state = AppState()
        XCTAssertEqual(state.saveAsNewChord(), .nothingToSave)
        state.toggle("C4"); state.toggle("E4"); state.toggle("G4")
        XCTAssertEqual(state.saveAsNewChord(), .saved)
        let first = state.savedChords[0]
        XCTAssertEqual(first.name, "Cmaj")
        XCTAssertEqual(state.activeChordID, first.id)
        XCTAssertFalse(state.hasChangesFromSaved)
        XCTAssertFalse(state.canUpdateActiveChord)

        state.toggle("B4")
        XCTAssertTrue(state.hasChangesFromSaved)
        XCTAssertTrue(state.canUpdateActiveChord)
        state.updateActiveChord()
        XCTAssertEqual(state.savedChords[0].name, "Cmaj7")
        XCTAssertEqual(state.savedChords[0].notes.count, 4)

        state.clearSelection()
        state.toggle("A3"); state.toggle("C4"); state.toggle("E4")
        state.saveAsNewChord()
        XCTAssertEqual(state.savedChords.map(\.name), ["Cmaj7", "Am"])

        state.selectChord(id: first.id)
        XCTAssertEqual(state.selectedNotes, ["C4", "E4", "G4", "B4"])
        state.deleteChord(id: first.id)
        XCTAssertNil(state.activeChordID)
        XCTAssertEqual(state.savedChords.map(\.name), ["Am"])
    }

    func testChordLimit() {
        var state = AppState()
        state.toggle("C4"); state.toggle("G4")
        for _ in 0..<AppState.maxSavedChords {
            XCTAssertEqual(state.saveAsNewChord(), .saved)
        }
        XCTAssertEqual(state.saveAsNewChord(), .limitReached)
        XCTAssertEqual(state.savedChords.count, AppState.maxSavedChords)
    }

    func testReorderAndNavigate() {
        var state = AppState()
        for notes: [Note] in [["C4", "E4", "G4"], ["F4", "A4", "C5"], ["G4", "B4", "D5"]] {
            state.selectedNotes = notes
            state.saveAsNewChord()
        }
        let ids = state.savedChords.map(\.id)
        state.moveChord(id: ids[2], to: ids[0])
        XCTAssertEqual(state.savedChords.map(\.name), ["Gmaj", "Cmaj", "Fmaj"])
        state.shiftChord(id: ids[2], by: 1)
        XCTAssertEqual(state.savedChords.map(\.name), ["Cmaj", "Gmaj", "Fmaj"])
        state.shiftChord(id: ids[0], by: -1)
        XCTAssertEqual(state.savedChords.map(\.name), ["Cmaj", "Gmaj", "Fmaj"])

        state.activeChordID = nil
        state.selectNextChord()
        XCTAssertEqual(state.activeChord?.name, "Cmaj")
        state.selectPreviousChord()
        XCTAssertEqual(state.activeChord?.name, "Fmaj")
        state.selectNextChord()
        XCTAssertEqual(state.activeChord?.name, "Cmaj")
        state.activeChordID = nil
        state.selectPreviousChord()
        XCTAssertEqual(state.activeChord?.name, "Fmaj")
    }

    func testFretboardEditing() {
        var state = AppState()
        let id = state.fretboards[0].id
        state.setCapo(15, for: id)
        XCTAssertEqual(state.fretboards[0].capo, 12)
        state.setStringCount(4, for: id)
        XCTAssertEqual(state.fretboards[0].tuning, ["E1", "A1", "D2", "G2"])
        state.setStringCount(9, for: id)
        XCTAssertEqual(state.fretboards[0].tuning.count, 4)
        state.adjustString(0, by: -2, for: id)
        XCTAssertEqual(state.fretboards[0].tuning[0], "D1")
        state.resetTuning(for: id)
        XCTAssertEqual(state.fretboards[0].tuning, ["E1", "A1", "D2", "G2"])
        XCTAssertEqual(state.fretboards[0].capo, 0)

        state.setFretboardCount(2)
        XCTAssertEqual(state.fretboards.count, 2)
        XCTAssertEqual(state.fretboards[0].id, id)
        state.setFretboardCount(0)
        XCTAssertTrue(state.fretboards.isEmpty)
        state.setFretboardCount(5)
        XCTAssertEqual(state.fretboards.count, 2)
    }

    func testPianoRange() {
        var state = AppState()
        XCTAssertEqual(state.pianoNotes.first, "C2")
        XCTAssertEqual(state.pianoNotes.last, "E6")
        state.setStringCount(5, for: state.fretboards[0].id)
        XCTAssertEqual(state.pianoNotes.first, "C0")
        state.setFretboardCount(0)
        XCTAssertEqual(state.pianoNotes.first, "C2")
    }

    func testPersistenceRoundTrip() throws {
        var state = AppState()
        state.toggle("C4"); state.toggle("E4"); state.toggle("G4")
        state.saveAsNewChord()
        state.selectedKey = nil
        state.darkMode = true
        state.playMode = .arpeggio
        state.setFretboardCount(2)
        state.setCapo(3, for: state.fretboards[1].id)

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(AppState.self, from: data)
        XCTAssertNil(decoded.selectedKey)
        XCTAssertTrue(decoded.darkMode)
        XCTAssertEqual(decoded.playMode, .arpeggio)
        XCTAssertEqual(decoded.fretboards, state.fretboards)
        XCTAssertEqual(decoded.savedChords, state.savedChords)
        // Selection isn't persisted.
        XCTAssertTrue(decoded.selectedNotes.isEmpty)

        let empty = try JSONDecoder().decode(AppState.self, from: Data("{}".utf8))
        XCTAssertEqual(empty.fretboards.count, 1)
        XCTAssertTrue(empty.showPiano)
    }
}

final class LoopTests: XCTestCase {
    func testLoopsSelectionWithoutSavedChords() {
        var state = AppState()
        state.toggle("C4")
        var loop = LoopSequencer(startingFrom: state)
        XCTAssertEqual(loop.nextBeat(&state), ["C4"])
        state.toggle("E4")
        XCTAssertEqual(loop.nextBeat(&state), ["C4", "E4"])
        state.clearSelection()
        XCTAssertNil(loop.nextBeat(&state))
    }

    func testCyclesSavedChordsFourTimesEach() {
        var state = AppState()
        for notes: [Note] in [["C4", "E4", "G4"], ["F4", "A4", "C5"], ["G4", "B4", "D5"]] {
            state.selectedNotes = notes
            state.saveAsNewChord()
        }
        state.selectChord(id: state.savedChords[1].id)
        var loop = LoopSequencer(startingFrom: state)
        var names: [String] = []
        for _ in 0..<12 {
            _ = loop.nextBeat(&state)
            names.append(state.activeChord!.name)
        }
        XCTAssertEqual(names, Array(repeating: "Fmaj", count: 4) + Array(repeating: "Gmaj", count: 4) + Array(repeating: "Cmaj", count: 4))
        XCTAssertEqual(state.selectedNotes, ["C4", "E4", "G4"])
    }

    func testBeatInterval() {
        XCTAssertEqual(LoopSequencer.beatInterval(noteCount: 3, mode: .chord), 0.8)
        XCTAssertEqual(LoopSequencer.beatInterval(noteCount: 3, mode: .arpeggio), 1.2, accuracy: 0.0001)
    }
}

final class PresetTests: XCTestCase {
    func testPresets() {
        XCTAssertEqual(TuningPreset.matching(Tunings.standard)?.id, "guitar-standard")
        XCTAssertNil(TuningPreset.matching(["C2", "C3", "C4", "C5", "C6", "C7"]))
        XCTAssertEqual(TuningPreset.categories.first, "Guitar (6 string)")
        XCTAssertEqual(TuningPreset.categories.count, 9)
        XCTAssertEqual(Set(TuningPreset.all.map(\.id)).count, TuningPreset.all.count)
        XCTAssertEqual(Tunings.stringLabel(number: 1, totalStrings: 6), "1 (High E)")
        XCTAssertEqual(Tunings.stringLabel(number: 1, totalStrings: 7), "String 1")
    }
}

final class SynthMixerTests: XCTestCase {
    private func peak(_ samples: ArraySlice<Float>) -> Float { samples.map(abs).max() ?? 0 }

    func testSilentWithNothingPlaying() {
        var mixer = SynthMixer(sampleRate: 44_100)
        XCTAssertEqual(peak(mixer.render(seconds: 0.1)[...]), 0)
    }

    func testNotePlaysThenEnds() {
        var mixer = SynthMixer(sampleRate: 44_100)
        mixer.playNote("A4")
        let sound = mixer.render(seconds: 0.5)
        XCTAssertGreaterThan(peak(sound[...]), 0.2)
        XCTAssertLessThanOrEqual(peak(sound[...]), 1)
        _ = mixer.render(seconds: 0.5)
        XCTAssertEqual(mixer.activeVoiceCount, 0)
        XCTAssertEqual(peak(mixer.render(seconds: 0.1)[...]), 0)
    }

    func testBigChordStaysInRange() {
        var mixer = SynthMixer(sampleRate: 48_000)
        mixer.playChord(["E2", "B2", "E3", "G#3", "B3", "E4", "G#4", "B4"])
        let sound = mixer.render(seconds: 1.0)
        XCTAssertGreaterThan(peak(sound[...]), 0.1)
        XCTAssertLessThanOrEqual(peak(sound[...]), 1)
    }

    func testNewChordCutsOffPrevious() {
        var mixer = SynthMixer(sampleRate: 44_100)
        mixer.playChord(["C4", "E4", "G4"])
        _ = mixer.render(seconds: 0.2)
        mixer.playChord(["D4", "F#4", "A4"])
        XCTAssertEqual(mixer.activeVoiceCount, 6)
        _ = mixer.render(seconds: 0.1)
        XCTAssertEqual(mixer.activeVoiceCount, 3)
    }

    func testArpeggioIsStaggered() {
        var mixer = SynthMixer(sampleRate: 44_100)
        mixer.playArpeggio(["C4", "E4", "G4"])
        let sound = mixer.render(seconds: 1.4)
        // The second note starts 0.4s in: just before it, only the decaying first note is sounding.
        let rate = 44_100.0
        XCTAssertGreaterThan(peak(sound[Int(0.05 * rate)..<Int(0.1 * rate)]), 0.1)
        XCTAssertGreaterThan(peak(sound[Int(0.85 * rate)..<Int(0.9 * rate)]), 0.1)
        XCTAssertEqual(mixer.activeVoiceCount, 1)
    }

    func testEnvelopeShape() {
        XCTAssertEqual(SynthMixer.envelope(at: 0, duration: 1, volume: 1), 0)
        XCTAssertEqual(SynthMixer.envelope(at: 0.02, duration: 1, volume: 1), 1, accuracy: 0.001)
        XCTAssertEqual(SynthMixer.envelope(at: 0.5, duration: 1, volume: 1), 0.7, accuracy: 0.001)
        XCTAssertEqual(SynthMixer.envelope(at: 1, duration: 1, volume: 1), 0)
        XCTAssertLessThan(SynthMixer.envelope(at: 0.9, duration: 1, volume: 1), 0.7)
    }
}

final class ChordSetTests: XCTestCase {
    private func saveChord(_ notes: [Note], in state: inout AppState) {
        state.selectedNotes = notes
        state.saveAsNewChord()
    }

    func testStartsWithOneEmptySet() {
        let state = AppState()
        XCTAssertEqual(state.chordSets.count, 1)
        XCTAssertEqual(state.activeSet.name, "Set 1")
        XCTAssertTrue(state.savedChords.isEmpty)
    }

    func testChordsBelongToTheActiveSet() {
        var state = AppState()
        saveChord(["C4", "E4", "G4"], in: &state)
        let first = state.activeSetID
        state.createSet()
        XCTAssertEqual(state.activeSet.name, "Set 2")
        XCTAssertTrue(state.savedChords.isEmpty)
        XCTAssertNil(state.activeChordID)
        saveChord(["A3", "C4", "E4"], in: &state)
        XCTAssertEqual(state.savedChords.map(\.name), ["Am"])

        state.selectSet(id: first)
        XCTAssertEqual(state.savedChords.map(\.name), ["Cmaj"])
    }

    func testEditingChordsBumpsModifiedDate() {
        var state = AppState()
        let before = state.activeSet.modifiedAt
        Thread.sleep(forTimeInterval: 0.01)
        saveChord(["C4", "E4", "G4"], in: &state)
        XCTAssertGreaterThan(state.activeSet.modifiedAt, before)

        // Selecting a chord doesn't change the set.
        let afterSave = state.activeSet.modifiedAt
        state.selectChord(id: state.savedChords[0].id)
        XCTAssertEqual(state.activeSet.modifiedAt, afterSave)
    }

    func testDefaultNamesKeepCounting() {
        var state = AppState()
        state.createSet()
        state.createSet()
        XCTAssertEqual(state.chordSets.map(\.name), ["Set 1", "Set 2", "Set 3"])
        state.deleteSet(id: state.chordSets[1].id)
        state.createSet()
        XCTAssertEqual(state.chordSets.map(\.name), ["Set 1", "Set 3", "Set 4"])
        state.renameSet(id: state.chordSets[0].id, to: "Verse")
        state.renameSet(id: state.chordSets[1].id, to: "   ")
        XCTAssertEqual(state.chordSets.map(\.name), ["Verse", "Set 3", "Set 4"])
    }

    func testDuplicate() {
        var state = AppState()
        saveChord(["C4", "E4", "G4"], in: &state)
        state.renameSet(id: state.activeSetID, to: "Chorus")
        let original = state.activeSet
        let copyID = state.duplicateSet(id: original.id)
        XCTAssertEqual(state.activeSetID, copyID)
        XCTAssertEqual(state.activeSet.name, "Chorus copy")
        XCTAssertEqual(state.savedChords.map(\.notes), original.chords.map(\.notes))
        XCTAssertNotEqual(state.savedChords[0].id, original.chords[0].id)
        XCTAssertEqual(state.chordSets.map(\.name), ["Chorus", "Chorus copy"])
    }

    func testDeleteSwitchesToNeighbor() {
        var state = AppState()
        let one = state.activeSetID
        let two = state.createSet()
        let three = state.createSet()
        state.selectSet(id: two)
        state.deleteSet(id: two)
        XCTAssertEqual(state.activeSetID, three)
        state.deleteSet(id: three)
        XCTAssertEqual(state.activeSetID, one)
        state.deleteSet(id: one)
        XCTAssertEqual(state.chordSets.count, 1)
        XCTAssertEqual(state.activeSet.name, "Set 1")
        XCTAssertNotEqual(state.activeSetID, one)
    }

    func testUpgradeFromSavedChords() throws {
        let legacy = """
        {"savedChords":[{"id":"\(UUID().uuidString)","name":"Cmaj","notes":[{"midi":60},{"midi":64},{"midi":67}]}],
         "darkMode":true,"fretboards":[]}
        """
        let state = try JSONDecoder().decode(AppState.self, from: Data(legacy.utf8))
        XCTAssertEqual(state.chordSets.count, 1)
        XCTAssertEqual(state.activeSet.name, "Set 1")
        XCTAssertEqual(state.savedChords.map(\.name), ["Cmaj"])
        XCTAssertTrue(state.darkMode)
    }

    func testSetsRoundTrip() throws {
        var state = AppState()
        saveChord(["C4", "E4", "G4"], in: &state)
        state.createSet()
        saveChord(["G3", "B3", "D4"], in: &state)
        let decoded = try JSONDecoder().decode(AppState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded.chordSets, state.chordSets)
        XCTAssertEqual(decoded.activeSetID, state.activeSetID)
    }

    func testReplaceChordSetsKeepsOrResetsActive() {
        var state = AppState()
        saveChord(["C4", "E4", "G4"], in: &state)
        let active = state.activeSet
        let other = ChordSet(name: "Other")
        state.replaceChordSets([other, active])
        XCTAssertEqual(state.activeSetID, active.id)
        XCTAssertNotNil(state.activeChordID)

        state.replaceChordSets([other])
        XCTAssertEqual(state.activeSetID, other.id)
        XCTAssertNil(state.activeChordID)
    }

    func testLoopUsesActiveSet() {
        var state = AppState()
        saveChord(["C4", "E4", "G4"], in: &state)
        saveChord(["F4", "A4", "C5"], in: &state)
        state.createSet()
        state.selectedNotes = ["D4"]
        var loop = LoopSequencer(startingFrom: state)
        XCTAssertEqual(loop.nextBeat(&state), ["D4"])
    }
}
