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

/// An entry in a chord set: a chord, or a scale (when `scale` is set).
public struct SavedChord: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    /// A chord's notes. A scale stores one octave going up, for playback (and so app versions that
    /// predate scales can still read it as a chord).
    public var notes: [Note]
    /// Set for a scale.
    public var scale: MusicalKey?

    public init(id: UUID = UUID(), name: String, notes: [Note], scale: MusicalKey? = nil) {
        self.id = id
        self.name = name
        self.notes = notes
        self.scale = scale
    }

    /// A saved scale, e.g. "A minor pentatonic".
    public init(id: UUID = UUID(), scale: MusicalKey) {
        self.init(id: id, name: scale.name(), notes: scale.ascendingNotes, scale: scale)
    }

    public var isScale: Bool { scale != nil }

    /// The chord's root pitch class (0 = C), read from its name ("C#m7/G" → C#); a scale's root.
    public var rootPitchClass: Int? {
        if let scale { return scale.root }
        return chordRoot(named: name, notes: notes)
    }

    /// A copy with a new ID, for duplicating sets.
    func copy() -> SavedChord { SavedChord(name: name, notes: notes, scale: scale) }
}

/// A chord's root pitch class (0 = C), read from its name ("C#m7/G" → C#). Names come from
/// `ChordIdentifier`, which always starts with the root; falls back to the lowest note.
public func chordRoot(named name: String, notes: [Note]) -> Int? {
    let prefix = name.hasPrefix(name.prefix(1) + "#") ? String(name.prefix(2)) : String(name.prefix(1))
    if let index = noteNamesSharp.firstIndex(of: prefix) { return index }
    return notes.min()?.pitchClass
}

/// Part of a set, like a song's verse or chorus.
public struct ChordSection: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    /// Empty for the unnamed section a set starts with.
    public var name: String
    public var chords: [SavedChord]

    public init(id: UUID = UUID(), name: String = "", chords: [SavedChord] = []) {
        self.id = id
        self.name = name
        self.chords = chords
    }

    /// The name to show: unnamed sections are numbered by position.
    public func displayName(index: Int) -> String {
        name.isEmpty ? "Section \(index + 1)" : name
    }
}

/// A named group of saved chords, like a song or practice set, divided into sections.
public struct ChordSet: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    /// Never empty.
    public var sections: [ChordSection]
    public var createdAt: Date
    /// Bumped on every edit; sync uses it to keep the newest version of each set.
    public var modifiedAt: Date

    /// A set with one unnamed section holding `chords`.
    public init(id: UUID = UUID(), name: String, chords: [SavedChord] = [], createdAt: Date = Date(), modifiedAt: Date? = nil) {
        self.init(id: id, name: name, sections: [ChordSection(chords: chords)], createdAt: createdAt, modifiedAt: modifiedAt)
    }

    public init(id: UUID = UUID(), name: String, sections: [ChordSection], createdAt: Date = Date(), modifiedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.sections = sections.isEmpty ? [ChordSection()] : sections
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt ?? createdAt
    }

    /// Every entry, section by section.
    public var chords: [SavedChord] { sections.flatMap(\.chords) }

    /// Where an entry is: its section's index and its index within that section.
    func position(of chordID: UUID) -> (section: Int, index: Int)? {
        for (sectionIndex, section) in sections.enumerated() {
            if let index = section.chords.firstIndex(where: { $0.id == chordID }) { return (sectionIndex, index) }
        }
        return nil
    }

    func section(containing chordID: UUID) -> ChordSection? {
        position(of: chordID).map { sections[$0.section] }
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, sections, createdAt, modifiedAt
        /// Before sections, a set held one list of chords. Still written (flattened) so older app
        /// versions on other devices can read the set.
        case chords
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        if let sections = try container.decodeIfPresent([ChordSection].self, forKey: .sections), !sections.isEmpty {
            self.sections = sections
        } else {
            sections = [ChordSection(chords: try container.decodeIfPresent([SavedChord].self, forKey: .chords) ?? [])]
        }
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(sections, forKey: .sections)
        try container.encode(chords, forKey: .chords)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modifiedAt, forKey: .modifiedAt)
    }
}

/// Everything the app displays, plus the operations the UI and keyboard shortcuts perform.
/// The selection itself isn't persisted (matching the web app); everything else is.
public struct AppState: Codable, Equatable, Sendable {
    /// Most chords and scales a set can hold, across all its sections.
    public static let maxSavedChords = 48
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
    public var noteLabelContent: NoteLabelContent = .names
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

    /// The active set's chords and scales, section by section.
    public var savedChords: [SavedChord] { activeSet.chords }

    /// The active set's chords without its scales: what the loop and the arrow keys step through.
    public var chordsOnly: [SavedChord] { savedChords.filter { !$0.isScale } }

    /// Edits the active set, marking it as modified if anything changed.
    private mutating func editActiveSet(_ change: (inout ChordSet) -> Void) {
        guard let index = chordSets.firstIndex(where: { $0.id == activeSetID }) else { return }
        var set = chordSets[index]
        change(&set)
        guard set != chordSets[index] else { return }
        set.modifiedAt = Date()
        chordSets[index] = set
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
            sections: original.sections.map { ChordSection(name: $0.name, chords: $0.chords.map { $0.copy() }) }
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
    public var canLoop: Bool { hasSelection || !chordsOnly.isEmpty }
    public var anyCapoActive: Bool { fretboards.contains { $0.capo > 0 } }
    public var sharpsOnly: Bool { noteLabelMode == .sharpsOnly }

    /// The selected chord's root pitch class, or nil with nothing selected.
    public var chordRootPitchClass: Int? {
        guard hasSelection else { return nil }
        return chordRoot(named: chordName ?? "", notes: selectedNotes)
    }

    /// How notes are labeled and colored right now.
    public var noteLabelContext: NoteLabelContext {
        NoteLabelContext(
            key: selectedKey,
            keyLabelMode: keyLabelMode,
            noteLabelMode: noteLabelMode,
            content: noteLabelContent,
            intervals: noteLabelContent == .intervals
                ? chordRootPitchClass.map { IntervalSpeller(root: $0, chord: selectedNotes) }
                : nil
        )
    }

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

    /// The section new chords go into: the active chord's, otherwise the last one.
    public var activeSectionID: UUID {
        if let activeChordID, let section = activeSet.section(containing: activeChordID) { return section.id }
        return activeSet.sections[activeSet.sections.count - 1].id
    }

    /// Adds an entry to `sectionID` (or the active section).
    private mutating func append(_ chord: SavedChord, to sectionID: UUID?) -> SaveResult {
        guard savedChords.count < Self.maxSavedChords else { return .limitReached }
        let target = sectionID ?? activeSectionID
        editActiveSet { set in
            let index = set.sections.firstIndex { $0.id == target } ?? set.sections.count - 1
            set.sections[index].chords.append(chord)
        }
        return .saved
    }

    @discardableResult
    public mutating func saveAsNewChord(in sectionID: UUID? = nil) -> SaveResult {
        guard canSaveAsNew, let chordName else { return .nothingToSave }
        let chord = SavedChord(name: chordName, notes: selectedNotes)
        let result = append(chord, to: sectionID)
        if result == .saved { activeChordID = chord.id }
        return result
    }

    /// Saves a scale and shows it on the instruments.
    @discardableResult
    public mutating func addScale(_ scale: MusicalKey, to sectionID: UUID? = nil) -> SaveResult {
        let result = append(SavedChord(scale: scale), to: sectionID)
        if result == .saved { selectedKey = scale }
        return result
    }

    public mutating func updateActiveChord() {
        guard canUpdateActiveChord, let chordName, let activeChordID else { return }
        let notes = selectedNotes
        editActiveSet { set in
            guard let position = set.position(of: activeChordID) else { return }
            set.sections[position.section].chords[position.index].name = chordName
            set.sections[position.section].chords[position.index].notes = notes
        }
    }

    /// Selects a saved chord's notes. A saved scale becomes the key instead, leaving the selected
    /// notes alone so a chord can be seen against it.
    public mutating func selectChord(id: UUID) {
        guard let chord = savedChords.first(where: { $0.id == id }) else { return }
        if let scale = chord.scale {
            selectedKey = scale
            return
        }
        selectedNotes = chord.notes
        activeChordID = chord.id
    }

    public mutating func deleteChord(id: UUID) {
        editActiveSet { set in
            for index in set.sections.indices { set.sections[index].chords.removeAll { $0.id == id } }
        }
        if activeChordID == id { activeChordID = nil }
    }

    /// Moves the dragged entry into the target entry's position, which may be in another section.
    public mutating func moveChord(id: UUID, to targetID: UUID) {
        guard id != targetID else { return }
        editActiveSet { set in
            guard let from = set.position(of: id), let to = set.position(of: targetID) else { return }
            let chord = set.sections[from.section].chords.remove(at: from.index)
            set.sections[to.section].chords.insert(chord, at: to.index)
        }
    }

    /// Moves an entry to the end of a section.
    public mutating func moveChord(id: UUID, toSection sectionID: UUID) {
        editActiveSet { set in
            guard let from = set.position(of: id),
                  let target = set.sections.firstIndex(where: { $0.id == sectionID }) else { return }
            if from.section == target && from.index == set.sections[target].chords.count - 1 { return }
            let chord = set.sections[from.section].chords.remove(at: from.index)
            set.sections[target].chords.append(chord)
        }
    }

    /// Whether `shiftChord` can move the entry that way: within its section, or across into the
    /// neighboring one.
    public func canShiftChord(id: UUID, by offset: Int) -> Bool {
        guard let position = activeSet.position(of: id) else { return false }
        let sections = activeSet.sections
        if offset < 0 { return position.index > 0 || position.section > 0 }
        return position.index < sections[position.section].chords.count - 1 || position.section < sections.count - 1
    }

    /// Moves an entry one place left (-1) or right (+1). At either end of a section it moves into
    /// the neighboring section.
    public mutating func shiftChord(id: UUID, by offset: Int) {
        guard canShiftChord(id: id, by: offset) else { return }
        editActiveSet { set in
            guard let from = set.position(of: id) else { return }
            let count = set.sections[from.section].chords.count
            let to = from.index + offset
            if (0..<count).contains(to) {
                set.sections[from.section].chords.swapAt(from.index, to)
            } else {
                let chord = set.sections[from.section].chords.remove(at: from.index)
                if offset < 0 {
                    set.sections[from.section - 1].chords.append(chord)
                } else {
                    set.sections[from.section + 1].chords.insert(chord, at: 0)
                }
            }
        }
    }

    public mutating func selectPreviousChord() {
        let chords = chordsOnly
        guard !chords.isEmpty else { return }
        let current = chords.firstIndex { $0.id == activeChordID } ?? -1
        let previous = current <= 0 ? chords.count - 1 : current - 1
        selectChord(id: chords[previous].id)
    }

    public mutating func selectNextChord() {
        let chords = chordsOnly
        guard !chords.isEmpty else { return }
        let current = chords.firstIndex { $0.id == activeChordID } ?? -1
        let next = current >= chords.count - 1 ? 0 : current + 1
        selectChord(id: chords[next].id)
    }

    // MARK: - Sections

    /// Adds a section to the end of the active set and returns its ID. Unnamed sections get
    /// numbered names first, so they keep their names when sections are rearranged.
    @discardableResult
    public mutating func addSection(named name: String? = nil) -> UUID {
        let section = ChordSection(name: "")
        editActiveSet { set in
            for index in set.sections.indices where set.sections[index].name.isEmpty {
                set.sections[index].name = set.sections[index].displayName(index: index)
            }
            var section = section
            let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            section.name = trimmed.isEmpty ? section.displayName(index: set.sections.count) : trimmed
            set.sections.append(section)
        }
        return section.id
    }

    /// Renames a section. Blank names are ignored.
    public mutating func renameSection(id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        editActiveSet { set in
            guard let index = set.sections.firstIndex(where: { $0.id == id }) else { return }
            set.sections[index].name = trimmed
        }
    }

    /// Deletes a section and its chords. The last section can't be deleted.
    public mutating func deleteSection(id: UUID) {
        guard activeSet.sections.count > 1 else { return }
        if let activeChordID, activeSet.section(containing: activeChordID)?.id == id { self.activeChordID = nil }
        editActiveSet { set in set.sections.removeAll { $0.id == id } }
    }

    /// Moves the dragged section into the target section's position.
    public mutating func moveSection(id: UUID, to targetID: UUID) {
        guard id != targetID else { return }
        editActiveSet { set in
            guard let from = set.sections.firstIndex(where: { $0.id == id }),
                  let to = set.sections.firstIndex(where: { $0.id == targetID }) else { return }
            let section = set.sections.remove(at: from)
            set.sections.insert(section, at: to)
        }
    }

    /// Moves a section up (-1) or down (+1).
    public mutating func shiftSection(id: UUID, by offset: Int) {
        editActiveSet { set in
            guard let from = set.sections.firstIndex(where: { $0.id == id }), set.sections.indices.contains(from + offset) else { return }
            set.sections.swapAt(from, from + offset)
        }
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
        case fretboards, chordSets, activeSetID, deletedSetIDs, playMode, showPiano, selectedKey, keyLabelMode, noteLabelMode, noteLabelContent, darkMode
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
        noteLabelContent = try container.decodeIfPresent(NoteLabelContent.self, forKey: .noteLabelContent) ?? .names
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
        try container.encode(noteLabelContent, forKey: .noteLabelContent)
        try container.encode(darkMode, forKey: .darkMode)
    }

    /// The persisted portion of the state, for change detection.
    public var persistedData: Data? { try? JSONEncoder().encode(self) }
}

/// Decides what the loop plays on each beat.
///
/// With two or more saved chords it walks through them, section by section, playing each four times
/// starting from the active chord. Scales are skipped. It can also stay within one section.
/// Otherwise it repeats the current selection (or the set's only chord, if nothing is selected).
public struct LoopSequencer: Sendable {
    public static let repeatsPerChord = 4

    /// The section being looped, or nil for the whole set.
    public let sectionID: UUID?
    private var chordIndex = 0
    private var playCount = 0

    public init(startingFrom state: AppState, sectionID: UUID? = nil) {
        self.sectionID = sectionID
        let chords = Self.chords(in: state, sectionID: sectionID)
        if chords.count > 1, let active = chords.firstIndex(where: { $0.id == state.activeChordID }) {
            chordIndex = active
        }
    }

    /// The chords the loop walks through.
    static func chords(in state: AppState, sectionID: UUID?) -> [SavedChord] {
        guard let sectionID else { return state.chordsOnly }
        let section = state.activeSet.sections.first { $0.id == sectionID }
        return section?.chords.filter { !$0.isScale } ?? []
    }

    /// Advances the loop, updating the selection when cycling saved chords.
    /// Returns the notes to play, or `nil` when there's nothing left and the loop should stop.
    public mutating func nextBeat(_ state: inout AppState) -> [Note]? {
        let chords = Self.chords(in: state, sectionID: sectionID)
        let notes: [Note]
        if chords.count > 1 {
            if chordIndex >= chords.count { chordIndex = 0 }
            let chord = chords[chordIndex]
            state.selectedNotes = chord.notes
            state.activeChordID = chord.id
            notes = chord.notes
            playCount += 1
            if playCount >= Self.repeatsPerChord {
                playCount = 0
                chordIndex = (chordIndex + 1) % chords.count
            }
        } else if let chord = chords.first, sectionID != nil || state.selectedNotes.isEmpty {
            // A one-chord section (or set, with nothing else selected) repeats that chord.
            state.selectedNotes = chord.notes
            state.activeChordID = chord.id
            notes = chord.notes
        } else {
            notes = state.selectedNotes
        }
        return notes.isEmpty ? nil : notes
    }

    /// Seconds until the next beat. Arpeggio notes are 0.4s apart, so the gap between loops matches.
    public static func beatInterval(noteCount: Int, mode: PlayMode) -> Double {
        switch mode {
        case .chord: return 0.8
        case .arpeggio: return Double(noteCount) * SynthMixer.arpeggioStep
        }
    }
}
