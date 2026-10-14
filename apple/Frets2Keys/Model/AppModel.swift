import Foundation
import Frets2KeysCore
import Observation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// App-wide state: wraps `AppState` with sound, loop playback, persistence, and sheet presentation.
@Observable
@MainActor
final class AppModel {
    private static let storageKey = "frets2keys_appState"

    var state: AppState {
        didSet {
            // Selection changes (note taps, loop beats) aren't persisted, so skip the encode.
            var comparable = oldValue
            comparable.selectedNotes = state.selectedNotes
            comparable.activeChordID = state.activeChordID
            if comparable != state { persistIfChanged() }

            let setsChanged = oldValue.chordSets != state.chordSets || oldValue.deletedSetIDs != state.deletedSetIDs
            if setsChanged && !isApplyingSync { sync?.localLibraryChanged() }
        }
    }

    private(set) var isLooping = false
    /// While looping, true from the start of a chord's second-to-last beat: the next chord's notes
    /// show in a light fill, fading in over `previewFadeDuration`.
    private(set) var isPreviewingNext = false
    private(set) var previewFadeDuration = 0.0

    /// The chord after the current one, when Show Next Chord is on (within the looping section).
    var nextChord: SavedChord? {
        guard state.showNextChord else { return nil }
        return state.chord(after: state.activeChordID, inSection: loopingSectionID)
    }

    /// Notes sounding right now, which flash on the instruments.
    private(set) var soundingNotes: Set<Note> = []
    /// How many overlapping flashes each note is in, so one ending doesn't cut another short.
    @ObservationIgnored private var flashCounts: [Note: Int] = [:]
    /// The section being looped, or nil when the loop covers the whole set (or isn't running).
    private(set) var loopingSectionID: UUID?
    var showChordLimitWarning = false
    var isSettingsPresented = false
    var isTutorialPresented = false
    /// Set by Settings' "View Tutorial" so the tutorial opens once the settings sheet is gone.
    var showTutorialAfterSettings = false

    /// The chord bank side panel. It has no text fields, so keyboard shortcuts keep working while it's open.
    var isChordBankPresented = false
    /// The section the chord bank adds to, when it was opened from one; otherwise the active section.
    var bankTargetSectionID: UUID?
    /// The set whose rename prompt is showing.
    var setBeingRenamed: UUID?
    /// The set whose delete confirmation is showing.
    var setPendingDeletion: UUID?
    /// The section whose rename prompt is showing.
    var sectionBeingRenamed: UUID?
    /// The section whose delete confirmation is showing.
    var sectionPendingDeletion: UUID?

    /// True while a sheet or prompt is up, so plain-key shortcuts stay out of the way of typing.
    var isSheetPresented: Bool {
        isSettingsPresented || isTutorialPresented || setBeingRenamed != nil || setPendingDeletion != nil
            || sectionBeingRenamed != nil || sectionPendingDeletion != nil
    }

    @ObservationIgnored private let synth = SynthEngine.shared
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var lastSavedData: Data?
    @ObservationIgnored private var loopTask: Task<Void, Never>?
    @ObservationIgnored private var warningTask: Task<Void, Never>?
    @ObservationIgnored private var sync: ChordLibrarySync?
    /// True while adopting chord sets merged from iCloud, so they aren't pushed straight back.
    @ObservationIgnored private var isApplyingSync = false

    init(defaults: UserDefaults = .standard, syncWithICloud: Bool = true) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(AppState.self, from: data) {
            state = saved
            lastSavedData = data
        } else {
            var initial = AppState()
            initial.darkMode = Self.systemPrefersDark
            state = initial
        }

        if syncWithICloud {
            let sync = ChordLibrarySync(
                readLocal: { [unowned self] in state.chordLibrary },
                applyMerged: { [unowned self] library in
                    isApplyingSync = true
                    state.apply(library)
                    isApplyingSync = false
                    if !state.canLoop { stopLoop() }
                }
            )
            self.sync = sync
            sync.start()
        }
    }

    private static var systemPrefersDark: Bool {
        #if canImport(UIKit)
        return UITraitCollection.current.userInterfaceStyle == .dark
        #elseif canImport(AppKit)
        return NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        #else
        return false
        #endif
    }

    private func persistIfChanged() {
        guard let data = state.persistedData, data != lastSavedData else { return }
        defaults.set(data, forKey: Self.storageKey)
        lastSavedData = data
    }

    // MARK: - Notes

    func toggle(_ note: Note) {
        if state.toggle(note) {
            synth.playNote(note, instrument: state.instrument)
        }
    }

    func clearSelection() {
        state.clearSelection()
        if !state.canLoop { stopLoop() }
    }

    func transpose(by semitones: Int) {
        state.transpose(by: semitones)
    }

    func play() {
        guard state.hasSelection else { return }
        sound(state.selectedNotes, mode: state.playMode)
    }

    // MARK: - Saved chords

    func saveAsNewChord() {
        handle(state.saveAsNewChord())
    }

    // MARK: - Chord bank

    /// Plays a chord without changing the selection.
    func preview(_ notes: [Note]) {
        sound(notes, mode: .chord)
    }

    func selectBankChord(_ notes: [Note]) {
        state.select(notes: notes)
        sound(notes, mode: state.playMode)
    }

    func addBankChord(_ notes: [Note]) {
        handle(state.addChord(notes: notes, to: bankTargetSectionID))
    }

    /// Opens the chord bank, adding to `section` (or the active section).
    func openChordBank(section: UUID? = nil) {
        bankTargetSectionID = section
        isChordBankPresented = true
    }

    // MARK: - Scales

    /// Plays a scale going up, without changing anything.
    func previewScale(_ scale: MusicalKey) {
        sound(scale.ascendingNotes, mode: .arpeggio)
    }

    /// Makes `scale` the key, so the instruments highlight it, and plays it.
    func showScale(_ scale: MusicalKey) {
        state.selectedKey = scale
        previewScale(scale)
    }

    func addScale(_ scale: MusicalKey) {
        handle(state.addScale(scale, to: bankTargetSectionID))
        if state.selectedKey == scale { previewScale(scale) }
    }

    // MARK: - Note labels

    func cycleNoteLabels() {
        state.noteLabelContent = state.noteLabelContent.next
    }

    private func handle(_ result: AppState.SaveResult) {
        if result == .limitReached {
            showChordLimitWarning = true
            warningTask?.cancel()
            warningTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                self?.showChordLimitWarning = false
            }
        }
    }

    func dismissChordLimitWarning() {
        warningTask?.cancel()
        showChordLimitWarning = false
    }

    func updateActiveChord() { state.updateActiveChord() }

    /// Selects a saved chord, or shows (and plays) a saved scale.
    func selectChord(_ id: UUID) {
        state.selectChord(id: id)
        if let scale = state.savedChords.first(where: { $0.id == id })?.scale {
            previewScale(scale)
        }
    }

    func selectPreviousChord() { state.selectPreviousChord() }
    func selectNextChord() { state.selectNextChord() }
    func moveChord(_ id: UUID, to targetID: UUID) { state.moveChord(id: id, to: targetID) }
    func moveChord(_ id: UUID, toSection sectionID: UUID) { state.moveChord(id: id, toSection: sectionID) }
    func shiftChord(_ id: UUID, by offset: Int) { state.shiftChord(id: id, by: offset) }

    func deleteChord(_ id: UUID) {
        state.deleteChord(id: id)
        if !state.canLoop { stopLoop() }
    }

    // MARK: - Chord sets

    func createSet() { state.createSet() }
    func selectSet(_ id: UUID) { state.selectSet(id: id) }
    func duplicateSet(_ id: UUID) { state.duplicateSet(id: id) }
    func renameSet(_ id: UUID, to name: String) { state.renameSet(id: id, to: name) }

    func deleteSet(_ id: UUID) {
        state.deleteSet(id: id)
        if !state.canLoop { stopLoop() }
    }

    // MARK: - Sections

    func addSection() {
        let id = state.addSection()
        // Name it straight away.
        sectionBeingRenamed = id
    }

    func renameSection(_ id: UUID, to name: String) { state.renameSection(id: id, to: name) }
    func moveSection(_ id: UUID, to targetID: UUID) { state.moveSection(id: id, to: targetID) }
    func shiftSection(_ id: UUID, by offset: Int) { state.shiftSection(id: id, by: offset) }

    /// Deletes a section, asking first if it has anything in it.
    func requestDeleteSection(_ id: UUID) {
        let section = state.activeSet.sections.first { $0.id == id }
        if section?.chords.isEmpty == true {
            deleteSection(id)
        } else {
            sectionPendingDeletion = id
        }
    }

    func deleteSection(_ id: UUID) {
        state.deleteSection(id: id)
        if loopingSectionID == id || !state.canLoop { stopLoop() }
    }

    // MARK: - Loop

    /// Starts or stops the loop. With `section`, loops just that section's chords (or switches the
    /// running loop over to it).
    func toggleLoop(section: UUID? = nil) {
        if isLooping {
            let switching = section != nil && section != loopingSectionID
            stopLoop()
            if switching { startLoop(section: section) }
        } else if section != nil || state.canLoop {
            startLoop(section: section)
        }
    }

    private func startLoop(section: UUID? = nil) {
        isLooping = true
        loopingSectionID = section
        var sequencer = LoopSequencer(startingFrom: state, sectionID: section)
        loopTask = Task { [weak self] in
            // Beats are booked on the audio clock a moment ahead, so they land exactly one interval
            // apart even when the task wakes late.
            var nextBeat: Double?
            while !Task.isCancelled, let self {
                // Worked out on a copy: the selection changes when the beat sounds, not before.
                var upcoming = self.state
                guard let notes = sequencer.nextBeat(&upcoming) else {
                    self.stopLoop()
                    return
                }
                let mode = self.state.playMode
                let now = self.synth.currentTime
                var beat = nextBeat ?? now
                // Fell behind (or the audio clock restarted after an output change): start afresh.
                if beat < now || beat > now + 10 { beat = now }
                let isChange = upcoming.selectedNotes != self.state.selectedNotes
                self.sound(notes, mode: mode, at: beat, isChordChange: isChange)
                let interval = LoopSequencer.beatInterval(noteCount: notes.count, mode: mode, tempo: self.state.tempo)
                let next = beat + interval
                nextBeat = next

                // Switch the instruments when the beat is heard, early by however long redrawing
                // them takes, so the new chord appears right on the hit.
                let visualDelay = self.synth.secondsUntilHeard(beat) - self.drawTime(isChordChange: isChange)
                try? await Task.sleep(for: .seconds(max(0, visualDelay)), tolerance: .milliseconds(3))
                guard !Task.isCancelled else { return }
                self.showBeat(selecting: upcoming.selectedNotes, chordID: upcoming.activeChordID)
                self.measureDraw(isChordChange: isChange)
                // From the second-to-last beat, the next chord's notes show in a light fill, fading
                // in over that beat.
                if let left = sequencer.beatsUntilChange, left <= 2, !self.isPreviewingNext, self.state.showNextChord {
                    self.previewFadeDuration = interval
                    self.isPreviewingNext = true
                }

                let wait = next - Self.loopLookahead - self.synth.currentTime
                try? await Task.sleep(for: .seconds(max(0, wait)), tolerance: .milliseconds(10))
            }
        }
    }

    // MARK: - Sound

    /// Switches instrument and plays a C major arpeggio so you hear it (unless a loop is playing).
    func setInstrument(_ instrument: SynthInstrument) {
        state.instrument = instrument
        if !isLooping {
            sound(["C4", "E4", "G4", "C5"], mode: .arpeggio)
        }
    }

    /// How long a note's flash lasts at most.
    private static let flashDuration = 0.4

    /// Plays notes (now, or at `time` on the audio clock) at the current tempo, flashing each one
    /// on the instruments as it sounds.
    private func sound(_ notes: [Note], mode: PlayMode, at time: Double? = nil, isChordChange: Bool = false) {
        guard !notes.isEmpty else { return }
        let step = state.arpeggioStep
        let start = time ?? synth.currentTime
        synth.play(notes, mode: mode, at: start, arpeggioStep: step, instrument: state.instrument)
        // Lit when heard (not when rendered), early by the time a redraw takes.
        let delay = max(0, synth.secondsUntilHeard(start) - drawTime(isChordChange: isChordChange))
        switch mode {
        case .chord:
            flash(notes, after: delay, for: Self.flashDuration)
        case .arpeggio:
            for (index, note) in notes.enumerated() {
                flash([note], after: delay + Double(index) * step, for: min(Self.flashDuration, step * 0.9))
            }
        }
    }

    /// Lights up `notes` after `delay` seconds, for `duration` seconds.
    private func flash(_ notes: [Note], after delay: Double, for duration: Double) {
        Task { [weak self] in
            if delay > 0.005 {
                try? await Task.sleep(for: .seconds(delay), tolerance: .milliseconds(5))
            }
            guard let self else { return }
            for note in notes { self.flashCounts[note, default: 0] += 1 }
            self.soundingNotes.formUnion(notes)
            try? await Task.sleep(for: .seconds(duration), tolerance: .milliseconds(10))
            for note in notes {
                let count = (self.flashCounts[note] ?? 1) - 1
                self.flashCounts[note] = count > 0 ? count : nil
                if count <= 0 { self.soundingNotes.remove(note) }
            }
        }
    }

    /// Moves the selection to the chord now sounding, switching straight over (and clearing the
    /// next-chord preview).
    private func showBeat(selecting notes: [Note], chordID: UUID?) {
        guard notes != state.selectedNotes || chordID != state.activeChordID else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isPreviewingNext = false
            state.selectedNotes = notes
            state.activeChordID = chordID
        }
    }

    /// How far ahead of each beat the loop wakes to book it: enough to cover output latency and
    /// the early start the visuals need.
    private static let loopLookahead = 0.3

    /// Recent time from changing what the instruments show to it being drawn, for beats that change
    /// the chord (a big redraw) and those that only flash notes. Visuals start this much early.
    @ObservationIgnored private var drawTimes: [Bool: Double] = [true: 0.12, false: 0.03]

    private func drawTime(isChordChange: Bool) -> Double {
        drawTimes[isChordChange] ?? 0
    }

    /// Times the redraw that follows a change (it finishes before the main queue's next turn) and
    /// folds it into the running estimate.
    private func measureDraw(isChordChange: Bool) {
        let changedAt = ContinuousClock.now
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let elapsed = ContinuousClock.now - changedAt
            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            let previous = self.drawTimes[isChordChange] ?? seconds
            self.drawTimes[isChordChange] = min(0.25, previous * 0.6 + seconds * 0.4)
        }
    }

    func stopLoop() {
        loopTask?.cancel()
        loopTask = nil
        isLooping = false
        loopingSectionID = nil
        isPreviewingNext = false
    }

    // MARK: - Appearance

    func toggleDarkMode() { state.darkMode.toggle() }
}
