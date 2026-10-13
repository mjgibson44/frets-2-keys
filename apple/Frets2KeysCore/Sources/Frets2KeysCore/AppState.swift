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

    /// The chord's root pitch class (0 = C), read from its name ("C#m7/G" → C#). Names come from
    /// `ChordIdentifier`, which always starts with the root; falls back to the lowest note.
    public var rootPitchClass: Int? {
        let prefix = name.hasPrefix(name.prefix(1) + "#") ? String(name.prefix(2)) : String(name.prefix(1))
        if let index = noteNamesSharp.firstIndex(of: prefix) { return index }
        return notes.min()?.pitchClass
    }
}

/// A named group of saved chords, like a song section or practice set.
public struct ChordSet: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var chords: [SavedChord]
    public var createdAt: Date
    /// Bumped on every edit; sync uses it to keep the newest version of each set.
    public var modifiedAt: Date

    public init(id: UUID = UUID(), name: String, chords: [SavedChord] = [], createdAt: Date = Date(), modifiedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.chords = chords
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt ?? createdAt
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
    /// Never empty: there's always at least one set, and `activeSetID` names one of them.
    public private(set) var chordSets: [ChordSet]
    public private(set) var activeSetID: UUID
    /// When each deleted set was deleted, so sync doesn't bring it back.
    public internal(set) var deletedSetIDs: [UUID: Date] = [:]
    public var playMode: PlayMode = .chord
    public var showPiano = true
    public var selectedKey: MusicalKey? = .cMajor
    public var keyLabelMode: KeyLabelMode = .showAll
    public var noteLabelMode: NoteLabelMode = .sharpsAndFlats
    public var darkMode = false

    public init() {
        let set = ChordSet(name: Self.defaultSetName(number: 1))
        chordSets = [set]
        activeSetID = set.id
    }

    // MARK: - Chord sets

    public var activeSet: ChordSet {
        chordSets.first { $0.id == activeSetID } ?? chordSets[0]
    }

    /// The active set's chords. Editing them marks the set as modified.
    public var savedChords: [SavedChord] {
        get { activeSet.chords }
        set {
            guard let index = chordSets.firstIndex(where: { $0.id == activeSetID }),
                  chordSets[index].chords != newValue else { return }
            chordSets[index].chords = newValue
            chordSets[index].modifiedAt = Date()
        }
    }

    static func defaultSetName(number: Int) -> String { "Set \(number)" }

    /// "Set N" with N one higher than any existing default-named set.
    public var nextDefaultSetName: String {
        let numbers = chordSets.compactMap { set -> Int? in
            guard set.name.hasPrefix("Set ") else { return nil }
            return Int(set.name.dropFirst(4))
        }
        return Self.defaultSetName(number: (numbers.max() ?? 0) + 1)
    }

    /// Creates an empty set with a default name and switches to it.
    @discardableResult
    public mutating func createSet() -> UUID {
        let set = ChordSet(name: nextDefaultSetName)
        chordSets.append(set)
        selectSet(id: set.id)
        return set.id
    }

    public mutating func selectSet(id: UUID) {
        guard chordSets.contains(where: { $0.id == id }), id != activeSetID else { return }
        activeSetID = id
        activeChordID = nil
    }

    /// Renames a set. Blank names are ignored.
    public mutating func renameSet(id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = chordSets.firstIndex(where: { $0.id == id }),
              chordSets[index].name != trimmed else { return }
        chordSets[index].name = trimmed
        chordSets[index].modifiedAt = Date()
    }

    /// Copies a set (with fresh chord IDs) to the end of the list and switches to the copy.
    @discardableResult
    public mutating func duplicateSet(id: UUID) -> UUID? {
        guard let index = chordSets.firstIndex(where: { $0.id == id }) else { return nil }
        let original = chordSets[index]
        let copy = ChordSet(
            name: "\(original.name) copy",
            chords: original.chords.map { SavedChord(name: $0.name, notes: $0.notes) }
        )
        chordSets.append(copy)
        selectSet(id: copy.id)
        return copy.id
    }

    /// Deletes a set. If it was active, the next set (or the previous one) becomes active;
    /// deleting the last remaining set leaves a fresh empty one.
    public mutating func deleteSet(id: UUID) {
        guard let index = chordSets.firstIndex(where: { $0.id == id }) else { return }
        chordSets.remove(at: index)
        deletedSetIDs[id] = Date()
        if chordSets.isEmpty {
            let set = ChordSet(name: Self.defaultSetName(number: 1))
            chordSets = [set]
        }
        if id == activeSetID {
            activeSetID = chordSets[min(index, chordSets.count - 1)].id
            activeChordID = nil
        }
    }

    /// Replaces all sets, e.g. with the result of merging in another device's changes.
    /// Keeps the active set if it still exists.
    public mutating func replaceChordSets(_ sets: [ChordSet]) {
        guard !sets.isEmpty else { return }
        chordSets = sets
        if !sets.contains(where: { $0.id == activeSetID }) {
            activeSetID = sets[0].id
            activeChordID = nil
        } else if let activeChordID, !activeSet.chords.contains(where: { $0.id == activeChordID }) {
            self.activeChordID = nil
        }
    }

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
        case fretboards, chordSets, activeSetID, deletedSetIDs, playMode, showPiano, selectedKey, keyLabelMode, noteLabelMode, darkMode
        /// Before chord sets existed, saved chords were stored directly.
        case savedChords
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fretboards = try container.decodeIfPresent([Fretboard].self, forKey: .fretboards) ?? [Fretboard()]
        if let sets = try container.decodeIfPresent([ChordSet].self, forKey: .chordSets), !sets.isEmpty {
            chordSets = sets
            let active = try container.decodeIfPresent(UUID.self, forKey: .activeSetID)
            activeSetID = sets.contains { $0.id == active } ? active! : sets[0].id
            deletedSetIDs = try container.decodeIfPresent([UUID: Date].self, forKey: .deletedSetIDs) ?? [:]
        } else {
            // Upgrade: the old single list of saved chords becomes "Set 1".
            let legacy = try container.decodeIfPresent([SavedChord].self, forKey: .savedChords) ?? []
            let set = ChordSet(name: Self.defaultSetName(number: 1), chords: legacy)
            chordSets = [set]
            activeSetID = set.id
        }
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
        try container.encode(chordSets, forKey: .chordSets)
        try container.encode(activeSetID, forKey: .activeSetID)
        try container.encode(deletedSetIDs, forKey: .deletedSetIDs)
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
