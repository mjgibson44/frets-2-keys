import Foundation

/// A chord type in the chord bank, e.g. "m7".
public struct ChordQuality: Identifiable, Hashable, Sendable {
    /// The suffix `ChordIdentifier` uses for this chord, e.g. "maj", "m7".
    public let id: String
    /// Short label for the picker.
    public let label: String
    /// Semitones above the root, lowest first; values above 12 reach into the next octave.
    public let intervals: [Int]
}

/// Common chords to choose from instead of building them note by note.
/// Voicings are close, root-position piano shapes starting in the octave below middle C.
public enum ChordBank {
    public static let qualities: [ChordQuality] = [
        .init(id: "maj", label: "Major", intervals: [0, 4, 7]),
        .init(id: "m", label: "Minor", intervals: [0, 3, 7]),
        .init(id: "7", label: "7", intervals: [0, 4, 7, 10]),
        .init(id: "maj7", label: "maj7", intervals: [0, 4, 7, 11]),
        .init(id: "m7", label: "m7", intervals: [0, 3, 7, 10]),
        .init(id: "6", label: "6", intervals: [0, 4, 7, 9]),
        .init(id: "m6", label: "m6", intervals: [0, 3, 7, 9]),
        .init(id: "sus2", label: "sus2", intervals: [0, 2, 7]),
        .init(id: "sus4", label: "sus4", intervals: [0, 5, 7]),
        .init(id: "7sus4", label: "7sus4", intervals: [0, 5, 7, 10]),
        .init(id: "add9", label: "add9", intervals: [0, 4, 7, 14]),
        .init(id: "9", label: "9", intervals: [0, 4, 7, 10, 14]),
        .init(id: "maj9", label: "maj9", intervals: [0, 4, 7, 11, 14]),
        .init(id: "m9", label: "m9", intervals: [0, 3, 7, 10, 14]),
        .init(id: "dim", label: "dim", intervals: [0, 3, 6]),
        .init(id: "dim7", label: "dim7", intervals: [0, 3, 6, 9]),
        .init(id: "m7b5", label: "m7♭5", intervals: [0, 3, 6, 10]),
        .init(id: "aug", label: "aug", intervals: [0, 4, 8]),
        .init(id: "5", label: "5 (power)", intervals: [0, 7, 12]),
    ]

    /// Lowest root used for voicings: C3, so roots run C3–B3 and chords sit around middle C.
    static let baseRoot = Note(midi: 48)

    /// The notes of `quality` built on `root` (a pitch class, 0 = C).
    public static func notes(root: Int, quality: ChordQuality) -> [Note] {
        let rootNote = baseRoot.transposed(by: ((root % 12) + 12) % 12)
        return quality.intervals.map { rootNote.transposed(by: $0) }
    }

    /// The chord's name as the app shows it, e.g. "C#m7".
    public static func name(root: Int, quality: ChordQuality) -> String {
        "\(noteNamesSharp[((root % 12) + 12) % 12])\(quality.id)"
    }
}

extension AppState {
    /// Selects `notes` and saves them as a new chord in the active set.
    @discardableResult
    public mutating func addChord(notes: [Note]) -> SaveResult {
        guard !notes.isEmpty else { return .nothingToSave }
        guard savedChords.count < Self.maxSavedChords else { return .limitReached }
        selectedNotes = notes
        return saveAsNewChord()
    }

    /// Selects `notes` without saving them, as if they'd been tapped.
    public mutating func select(notes: [Note]) {
        selectedNotes = notes
        activeChordID = nil
    }
}

/// A chord built on one degree of a key, e.g. "ii" = Dm in C major.
public struct DiatonicChord: Hashable, Sendable {
    public let numeral: String
    /// Root pitch class, 0 = C.
    public let root: Int
    public let quality: ChordQuality
}

extension MusicalKey {
    /// The chords built by stacking thirds on each scale degree: triads, or seventh chords.
    public func diatonicChords(sevenths: Bool = false) -> [DiatonicChord] {
        let scale = pitchClasses
        let numerals = ["I", "II", "III", "IV", "V", "VI", "VII"]
        return scale.indices.compactMap { degree in
            let stack = sevenths ? [0, 2, 4, 6] : [0, 2, 4]
            let root = scale[degree]
            // Semitones above the root for each stacked scale tone (a seventh stays within the octave).
            let intervals = stack.map { step in (scale[(degree + step) % 7] - root + 12) % 12 }
            guard let quality = ChordBank.qualities.first(where: { $0.intervals == intervals }) else { return nil }
            let isMinorish = intervals[1] == 3
            var numeral = isMinorish ? numerals[degree].lowercased() : numerals[degree]
            switch quality.id {
            case "dim": numeral += "°"
            case "m7b5": numeral += "ø7"
            case "maj7": numeral += "maj7"
            case "7", "m7": numeral += "7"
            default: break
            }
            return DiatonicChord(numeral: numeral, root: root, quality: quality)
        }
    }
}
