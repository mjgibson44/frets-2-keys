import Foundation
import Frets2KeysCore
import Observation
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
    var showChordLimitWarning = false
    var isSettingsPresented = false
    var isTutorialPresented = false
    /// Set by Settings' "View Tutorial" so the tutorial opens once the settings sheet is gone.
    var showTutorialAfterSettings = false

    var isChordBankPresented = false
    /// The set whose rename prompt is showing.
    var setBeingRenamed: UUID?
    /// The set whose delete confirmation is showing.
    var setPendingDeletion: UUID?

    /// True while a sheet or prompt is up, so plain-key shortcuts stay out of the way of typing.
    var isSheetPresented: Bool {
        isSettingsPresented || isTutorialPresented || isChordBankPresented
            || setBeingRenamed != nil || setPendingDeletion != nil
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
            synth.playNote(note)
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
        synth.play(state.selectedNotes, mode: state.playMode)
    }

    // MARK: - Saved chords

    func saveAsNewChord() {
        handle(state.saveAsNewChord())
    }

    // MARK: - Chord bank

    /// Plays a chord without changing the selection.
    func preview(_ notes: [Note]) {
        synth.play(notes, mode: .chord)
    }

    func selectBankChord(_ notes: [Note]) {
        state.select(notes: notes)
        synth.play(notes, mode: state.playMode)
    }

    func addBankChord(_ notes: [Note]) {
        handle(state.addChord(notes: notes))
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
    func selectChord(_ id: UUID) { state.selectChord(id: id) }
    func selectPreviousChord() { state.selectPreviousChord() }
    func selectNextChord() { state.selectNextChord() }
    func moveChord(_ id: UUID, to targetID: UUID) { state.moveChord(id: id, to: targetID) }
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

    // MARK: - Loop

    func toggleLoop() {
        if isLooping {
            stopLoop()
        } else if state.canLoop {
            startLoop()
        }
    }

    private func startLoop() {
        isLooping = true
        var sequencer = LoopSequencer(startingFrom: state)
        loopTask = Task { [weak self] in
            while !Task.isCancelled, let self {
                guard let notes = sequencer.nextBeat(&self.state) else {
                    self.stopLoop()
                    return
                }
                let mode = self.state.playMode
                self.synth.play(notes, mode: mode)
                let interval = LoopSequencer.beatInterval(noteCount: notes.count, mode: mode)
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stopLoop() {
        loopTask?.cancel()
        loopTask = nil
        isLooping = false
    }

    // MARK: - Appearance

    func toggleDarkMode() { state.darkMode.toggle() }
}
