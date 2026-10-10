import Foundation

public enum KeyLabelMode: String, Codable, Sendable, CaseIterable {
    case onlyInKey
    case showAll
}

public enum NoteLabelMode: String, Codable, Sendable, CaseIterable {
    case sharpsAndFlats
    case sharpsOnly
}

/// Which palette entry a note's badge uses. The app maps these to concrete colors.
public enum NoteColorRole: Hashable, Sendable {
    /// In-key note, indexed by scale degree 0-6.
    case scaleDegree(Int)
    /// Selected note outside the key, indexed 0-4 among the key's chromatic notes.
    case outOfKey(Int)
    /// Selected note with no key chosen, indexed by pitch class 0-11.
    case chromatic(Int)
}

/// How a single note position (a fret or a piano key) should be drawn.
public struct NoteAppearance: Equatable, Sendable {
    public enum Style: Equatable, Sendable {
        /// Selected: solid color, white text, larger badge.
        case selected(NoteColorRole)
        /// Not selected but in the current key: tinted badge with a border.
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

    public init(note: Note, isSelected: Bool, key: MusicalKey?, keyLabelMode: KeyLabelMode, noteLabelMode: NoteLabelMode) {
        let inKey = isNote(note, inKey: key)
        let degree = key?.scaleDegree(of: note)

        if isSelected {
            style = .selected(Self.colorRole(for: note, key: key))
        } else if let degree {
            style = .inKey(scaleDegree: degree)
        } else {
            style = .plain
        }

        showsLabel = !(keyLabelMode == .onlyInKey && !inKey && !isSelected)
        isDimmed = keyLabelMode == .showAll && !inKey && !isSelected
        label = displayName(for: note, key: key, sharpsOnly: noteLabelMode == .sharpsOnly)
    }

    /// Color role for a selected note (also used for the chips in the header).
    public static func colorRole(for note: Note, key: MusicalKey?) -> NoteColorRole {
        if let key {
            if let degree = key.scaleDegree(of: note) { return .scaleDegree(degree) }
            if let index = key.chromaticIndex(of: note) { return .outOfKey(index) }
        }
        return .chromatic(note.pitchClass)
    }
}
