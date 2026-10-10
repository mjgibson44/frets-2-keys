import Foundation

public enum PlayMode: String, Codable, Sendable, CaseIterable {
    case chord
    case arpeggio
}

public struct Fretboard: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    /// Lowest string first.
    public var tuning: [Note]
    public var capo: Int

    public init(id: UUID = UUID(), tuning: [Note] = Tunings.standard, capo: Int = 0) {
        self.id = id
        self.tuning = tuning
        self.capo = capo
    }
}

public struct SavedChord: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var notes: [Note]

    public init(id: UUID = UUID(), name: String, notes: [Note]) {
        self.id = id
        self.name = name
        self.notes = notes
    }
}

/// Everything the app displays, plus the operations the UI and keyboard shortcuts perform.
/// The selection itself isn't persisted (matching the web app); everything else is.
public struct AppState: Codable, Equatable, Sendable {
    public static let maxSavedChords = 20
    public static let maxFretboards = 2
    /// Highest piano key shown.
    public static let pianoTopNote: Note = "E6"

    public var selectedNotes: [Note] = []
    public var activeChordID: UUID?
    public var fretboards: [Fretboard] = [Fretboard()]
    public var savedChords: [SavedChord] = []
    public var playMode: PlayMode = .chord
    public var showPiano = true
    public var selectedKey: MusicalKey? = .cMajor
    public var keyLabelMode: KeyLabelMode = .showAll
    public var noteLabelMode: NoteLabelMode = .sharpsAndFlats
    public var darkMode = false

    public init() {}

    // MARK: - Derived values

    public var chordName: String? { ChordIdentifier.identify(selectedNotes) }

    public var activeChord: SavedChord? {
        savedChords.first { $0.id == activeChordID }
    }

    public var hasChangesFromSaved: Bool {
        guard let activeChord else { return false }
        return activeChord.notes != selectedNotes
    }

    public var hasSelection: Bool { !selectedNotes.isEmpty }
    public var canSaveAsNew: Bool { hasSelection && chordName != nil }
    public var canUpdateActiveChord: Bool { activeChordID != nil && canSaveAsNew && hasChangesFromSaved }
    public var canLoop: Bool { hasSelection || !savedChords.isEmpty }
    public var anyCapoActive: Bool { fretboards.contains { $0.capo > 0 } }
    public var sharpsOnly: Bool { noteLabelMode == .sharpsOnly }

    /// Piano keys from the C at or below the lowest open string up to E6.
    public var pianoNotes: [Note] {
        let allOpenStrings = fretboards.flatMap(\.tuning)
        let lowest = (allOpenStrings.isEmpty ? Tunings.standard : allOpenStrings).min()!
        let start = Note(midi: (lowest.midi / 12) * 12)
        return noteRange(from: start, through: Self.pianoTopNote)
    }

    public func isSelected(_ note: Note) -> Bool { selectedNotes.contains(note) }

    // MARK: - Selection

    /// Adds the note to the selection, or removes it if it's already selected.
    /// Returns `true` when the note was added (the caller plays it).
    @discardableResult
    public mutating func toggle(_ note: Note) -> Bool {
        if let index = selectedNotes.firstIndex(of: note) {
            selectedNotes.remove(at: index)
            return false
        }
        selectedNotes.append(note)
        return true
    }

    public mutating func clearSelection() {
        selectedNotes = []
        activeChordID = nil
    }

    public mutating func transpose(by semitones: Int) {
        guard hasSelection else { return }
        // Transposed notes may fall outside the key, so make sure they stay visible.
        if keyLabelMode == .onlyInKey { keyLabelMode = .showAll }
        selectedNotes = selectedNotes.map { note in
            let moved = note.transposed(by: semitones)
            return (0...127).contains(moved.midi) ? moved : note
        }
    }

    // MARK: - Saved chords

    public enum SaveResult: Equatable {
        case saved
        case limitReached
        case nothingToSave
    }

    @discardableResult
    public mutating func saveAsNewChord() -> SaveResult {
        guard canSaveAsNew, let chordName else { return .nothingToSave }
        guard savedChords.count < Self.maxSavedChords else { return .limitReached }
        let chord = SavedChord(name: chordName, notes: selectedNotes)
        savedChords.append(chord)
        activeChordID = chord.id
        return .saved
    }

    public mutating func updateActiveChord() {
        guard canUpdateActiveChord, let chordName,
              let index = savedChords.firstIndex(where: { $0.id == activeChordID }) else { return }
        savedChords[index].name = chordName
        savedChords[index].notes = selectedNotes
    }

    public mutating func selectChord(id: UUID) {
        guard let chord = savedChords.first(where: { $0.id == id }) else { return }
        selectedNotes = chord.notes
        activeChordID = chord.id
    }

    public mutating func deleteChord(id: UUID) {
        savedChords.removeAll { $0.id == id }
        if activeChordID == id { activeChordID = nil }
    }

    /// Moves the dragged chord into the target chord's position.
    public mutating func moveChord(id: UUID, to targetID: UUID) {
        guard id != targetID,
              let from = savedChords.firstIndex(where: { $0.id == id }),
              let to = savedChords.firstIndex(where: { $0.id == targetID }) else { return }
        let chord = savedChords.remove(at: from)
        savedChords.insert(chord, at: to)
    }

    /// Moves a chord one place left (-1) or right (+1).
    public mutating func shiftChord(id: UUID, by offset: Int) {
        guard let from = savedChords.firstIndex(where: { $0.id == id }) else { return }
        let to = from + offset
        guard savedChords.indices.contains(to) else { return }
        savedChords.swapAt(from, to)
    }

    public mutating func selectPreviousChord() {
        guard !savedChords.isEmpty else { return }
        let current = savedChords.firstIndex { $0.id == activeChordID } ?? -1
        let previous = current <= 0 ? savedChords.count - 1 : current - 1
        selectChord(id: savedChords[previous].id)
    }

    public mutating func selectNextChord() {
        guard !savedChords.isEmpty else { return }
        let current = savedChords.firstIndex { $0.id == activeChordID } ?? -1
        let next = current >= savedChords.count - 1 ? 0 : current + 1
        selectChord(id: savedChords[next].id)
    }

    // MARK: - Instruments

    public mutating func setFretboardCount(_ count: Int) {
        let count = min(max(count, 0), Self.maxFretboards)
        if count < fretboards.count {
            fretboards.removeLast(fretboards.count - count)
        }
        while fretboards.count < count {
            fretboards.append(Fretboard())
        }
    }

    private mutating func updateFretboard(_ id: UUID, _ change: (inout Fretboard) -> Void) {
        guard let index = fretboards.firstIndex(where: { $0.id == id }) else { return }
        change(&fretboards[index])
    }

    public mutating func setTuning(_ tuning: [Note], for id: UUID) {
        updateFretboard(id) { $0.tuning = tuning }
    }

    public mutating func setCapo(_ capo: Int, for id: UUID) {
        updateFretboard(id) { $0.capo = min(max(capo, 0), Tunings.maxCapo) }
    }

    /// Changing the string count switches to that count's default tuning.
    public mutating func setStringCount(_ count: Int, for id: UUID) {
        guard (Tunings.minStrings...Tunings.maxStrings).contains(count) else { return }
        updateFretboard(id) { $0.tuning = Tunings.defaultTuning(stringCount: count) }
    }

    public mutating func setString(_ stringIndex: Int, to note: Note, for id: UUID) {
        updateFretboard(id) { fretboard in
            guard fretboard.tuning.indices.contains(stringIndex), (0...127).contains(note.midi) else { return }
            fretboard.tuning[stringIndex] = note
        }
    }

    public mutating func adjustString(_ stringIndex: Int, by semitones: Int, for id: UUID) {
        guard let fretboard = fretboards.first(where: { $0.id == id }),
              fretboard.tuning.indices.contains(stringIndex) else { return }
        setString(stringIndex, to: fretboard.tuning[stringIndex].transposed(by: semitones), for: id)
    }

    /// Restores the default tuning for the current string count and removes the capo.
    public mutating func resetTuning(for id: UUID) {
        updateFretboard(id) {
            $0.tuning = Tunings.defaultTuning(stringCount: $0.tuning.count)
            $0.capo = 0
        }
    }

    // MARK: - Persistence

    private enum CodingKeys: String, CodingKey {
        case fretboards, savedChords, playMode, showPiano, selectedKey, keyLabelMode, noteLabelMode, darkMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fretboards = try container.decodeIfPresent([Fretboard].self, forKey: .fretboards) ?? [Fretboard()]
        savedChords = try container.decodeIfPresent([SavedChord].self, forKey: .savedChords) ?? []
        playMode = try container.decodeIfPresent(PlayMode.self, forKey: .playMode) ?? .chord
        showPiano = try container.decodeIfPresent(Bool.self, forKey: .showPiano) ?? true
        // Always encoded (as null when "No key" is chosen), so absence also means no key.
        selectedKey = try container.decodeIfPresent(MusicalKey.self, forKey: .selectedKey)
        keyLabelMode = try container.decodeIfPresent(KeyLabelMode.self, forKey: .keyLabelMode) ?? .showAll
        noteLabelMode = try container.decodeIfPresent(NoteLabelMode.self, forKey: .noteLabelMode) ?? .sharpsAndFlats
        darkMode = try container.decodeIfPresent(Bool.self, forKey: .darkMode) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fretboards, forKey: .fretboards)
        try container.encode(savedChords, forKey: .savedChords)
        try container.encode(playMode, forKey: .playMode)
        try container.encode(showPiano, forKey: .showPiano)
        try container.encode(selectedKey, forKey: .selectedKey)
        try container.encode(keyLabelMode, forKey: .keyLabelMode)
        try container.encode(noteLabelMode, forKey: .noteLabelMode)
        try container.encode(darkMode, forKey: .darkMode)
    }

    /// The persisted portion of the state, for change detection.
    public var persistedData: Data? { try? JSONEncoder().encode(self) }
}

/// Decides what the loop plays on each beat.
///
/// With two or more saved chords it walks through them, playing each four times starting from the
/// active chord. Otherwise it repeats the current selection.
public struct LoopSequencer: Sendable {
    public static let repeatsPerChord = 4

    private var chordIndex = 0
    private var playCount = 0

    public init(startingFrom state: AppState) {
        if state.savedChords.count > 1, let active = state.savedChords.firstIndex(where: { $0.id == state.activeChordID }) {
            chordIndex = active
        }
    }

    /// Advances the loop, updating the selection when cycling saved chords.
    /// Returns the notes to play, or `nil` when there's nothing left and the loop should stop.
    public mutating func nextBeat(_ state: inout AppState) -> [Note]? {
        let notes: [Note]
        if state.savedChords.count > 1 {
            if chordIndex >= state.savedChords.count { chordIndex = 0 }
            let chord = state.savedChords[chordIndex]
            state.selectedNotes = chord.notes
            state.activeChordID = chord.id
            notes = chord.notes
            playCount += 1
            if playCount >= Self.repeatsPerChord {
                playCount = 0
                chordIndex = (chordIndex + 1) % state.savedChords.count
            }
        } else {
            notes = state.selectedNotes
        }
        return notes.isEmpty ? nil : notes
    }

    /// Seconds until the next beat. Arpeggio notes are 0.4s apart, so the gap between loops matches.
    public static func beatInterval(noteCount: Int, mode: PlayMode) -> Double {
        switch mode {
        case .chord: return 0.8
        case .arpeggio: return Double(noteCount) * 0.4
        }
    }
}
