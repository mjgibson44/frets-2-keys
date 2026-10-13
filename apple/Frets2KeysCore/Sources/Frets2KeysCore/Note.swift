import Foundation

/// Sharp spellings of the 12 pitch classes, starting at C.
public let noteNamesSharp = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
/// Flat spellings of the 12 pitch classes, starting at C.
public let noteNamesFlat = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

/// A single pitch, stored as a MIDI note number (C4 = 60).
public struct Note: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public var midi: Int

    public init(midi: Int) {
        self.midi = midi
    }

    /// Parses scientific pitch notation such as "E2", "F#3", "Bb4" (case-insensitive letter).
    public init?(parsing string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first,
              let letterIndex = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11][String(first).uppercased()]
        else { return nil }

        var rest = trimmed.dropFirst()
        var offset = 0
        if let accidental = rest.first {
            if accidental == "#" || accidental == "♯" {
                offset = 1
                rest = rest.dropFirst()
            } else if accidental == "b" || accidental == "♭" {
                offset = -1
                rest = rest.dropFirst()
            }
        }
        guard !rest.isEmpty, rest.allSatisfy(\.isNumber), let octave = Int(rest) else { return nil }
        let midi = (octave + 1) * 12 + letterIndex + offset
        guard (0...127).contains(midi) else { return nil }
        self.midi = midi
    }

    /// 0 = C, 1 = C#, ... 11 = B
    public var pitchClass: Int { ((midi % 12) + 12) % 12 }
    public var octave: Int { Int((Double(midi) / 12).rounded(.down)) - 1 }
    /// Sharp name without octave, e.g. "C#".
    public var name: String { noteNamesSharp[pitchClass] }
    public var isBlackKey: Bool { name.contains("#") }
    /// Sharp name with octave, e.g. "C#4".
    public var description: String { "\(name)\(octave)" }

    public var frequency: Double { 440 * pow(2, Double(midi - 69) / 12) }

    public func transposed(by semitones: Int) -> Note { Note(midi: midi + semitones) }

    public static func < (lhs: Note, rhs: Note) -> Bool { lhs.midi < rhs.midi }
}

extension Note: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        guard let note = Note(parsing: value) else { preconditionFailure("Invalid note literal: \(value)") }
        self = note
    }
}

/// Splits a display name like "Bb" into its letter ("B") and accidental ("b").
public func splitNoteDisplay(_ displayName: String) -> (letter: String, accidental: String?) {
    guard displayName.count > 1 else { return (displayName, nil) }
    return (String(displayName.prefix(1)), String(displayName.dropFirst()))
}

/// The notes from `start` through `end`, inclusive.
public func noteRange(from start: Note, through end: Note) -> [Note] {
    guard start.midi <= end.midi else { return [] }
    return (start.midi...end.midi).map(Note.init(midi:))
}
