import Foundation

public enum KeyLabelMode: String, Codable, Sendable, CaseIterable {
    case onlyInKey
    case showAll
}

public enum NoteLabelMode: String, Codable, Sendable, CaseIterable {
    case sharpsAndFlats
    case sharpsOnly
}

/// What the badges on the instruments say.
public enum NoteLabelContent: String, Codable, Sendable, CaseIterable, Identifiable {
    /// Note names: C, E♭, F♯...
    case names
    /// Scale degrees in the key: 1, 2, ♭3...
    case degrees
    /// Intervals above the selected chord's root: R, 3, 5, ♭7...
    case intervals

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .names: return "Notes"
        case .degrees: return "Degrees"
        case .intervals: return "Intervals"
        }
    }

    /// The next option, for a shortcut that cycles through them.
    public var next: NoteLabelContent {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

/// Which palette entry a note's badge uses. The app maps these to concrete colors.
public enum NoteColorRole: Hashable, Sendable {
    /// In-key note, colored by its degree number 1-7 (as index 0-6), so ♭3 and 3 share a color.
    case scaleDegree(Int)
    /// Selected note outside the key, indexed 0-6 among the key's chromatic notes.
    case outOfKey(Int)
    /// Selected note with no key chosen, indexed by pitch class 0-11.
    case chromatic(Int)
}

/// Everything besides the note itself that decides how notes are labeled and colored. Worked out
/// once per drawing pass rather than for every fret.
public struct NoteLabelContext: Equatable, Sendable {
    public var key: MusicalKey?
    public var keyLabelMode: KeyLabelMode
    public var noteLabelMode: NoteLabelMode
    public var content: NoteLabelContent
    /// Present when labeling by interval and there's a chord to measure from.
    public var intervals: IntervalSpeller?

    public init(
        key: MusicalKey?,
        keyLabelMode: KeyLabelMode = .showAll,
        noteLabelMode: NoteLabelMode = .sharpsAndFlats,
        content: NoteLabelContent = .names,
        intervals: IntervalSpeller? = nil
    ) {
        self.key = key
        self.keyLabelMode = keyLabelMode
        self.noteLabelMode = noteLabelMode
        self.content = content
        self.intervals = intervals
    }

    /// The label for a note. Degrees need a key and intervals need a chord; without them, notes
    /// fall back to their names.
    public func label(for note: Note) -> String {
        switch content {
        case .degrees:
            if let key { return key.degree(of: note).label }
        case .intervals:
            if let intervals { return intervals.label(for: note) }
        case .names:
            break
        }
        return displayName(for: note, key: key, sharpsOnly: noteLabelMode == .sharpsOnly)
    }
}

/// How a single note position (a fret or a piano key) should be drawn.
public struct NoteAppearance: Equatable, Sendable {
    public enum Style: Equatable, Sendable {
        /// Selected: solid color, white text, larger badge.
        case selected(NoteColorRole)
        /// Not selected but in the current key: tinted badge with a border. Colored by degree
        /// number (0-6), like `NoteColorRole.scaleDegree`.
        case inKey(scaleDegree: Int)
        /// Plain text label.
        case plain
    }

    public var style: Style
    /// Whether the label is drawn at all (hidden for out-of-key notes in "only in key" mode).
    public var showsLabel: Bool
    /// Out-of-key notes are dimmed in "show all" mode.
    public var isDimmed: Bool
    public var label: String

    public var isSelected: Bool {
        if case .selected = style { return true }
        return false
    }

    public init(note: Note, isSelected: Bool, context: NoteLabelContext) {
        let key = context.key
        let inKey = isNote(note, inKey: key)

        if isSelected {
            style = .selected(Self.colorRole(for: note, key: key))
        } else if let key, key.contains(note) {
            style = .inKey(scaleDegree: key.degree(of: note).number - 1)
        } else {
            style = .plain
        }

        showsLabel = !(context.keyLabelMode == .onlyInKey && !inKey && !isSelected)
        isDimmed = context.keyLabelMode == .showAll && !inKey && !isSelected
        label = context.label(for: note)
    }

    public init(note: Note, isSelected: Bool, key: MusicalKey?, keyLabelMode: KeyLabelMode, noteLabelMode: NoteLabelMode) {
        self.init(note: note, isSelected: isSelected, context: NoteLabelContext(key: key, keyLabelMode: keyLabelMode, noteLabelMode: noteLabelMode))
    }

    /// Color role for a selected note (also used for the chips in the header).
    public static func colorRole(for note: Note, key: MusicalKey?) -> NoteColorRole {
        if let key {
            if key.contains(note) { return .scaleDegree(key.degree(of: note).number - 1) }
            if let index = key.chromaticIndex(of: note) { return .outOfKey(index) }
        }
        return .chromatic(note.pitchClass)
    }
}
