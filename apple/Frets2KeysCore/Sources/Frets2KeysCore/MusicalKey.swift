import Foundation

/// A scale degree spelled against the major scale, e.g. "♭3" = a minor third above the root.
/// This is the usual way to number scales: natural minor is 1 2 ♭3 4 5 ♭6 ♭7.
public struct Degree: Hashable, Sendable, CustomStringConvertible {
    /// 1-7.
    public let number: Int
    /// -1 for flat, +1 for sharp.
    public let accidental: Int

    public init(_ number: Int, _ accidental: Int = 0) {
        self.number = number
        self.accidental = accidental
    }

    private static let majorSemitones = [0, 2, 4, 5, 7, 9, 11]

    /// Semitones above the root, 0-11.
    public var semitones: Int { (Self.majorSemitones[number - 1] + accidental + 12) % 12 }

    /// e.g. "♭3", "♯4", "5".
    public var label: String { accidentalSymbol(accidental) + "\(number)" }
    public var description: String { label }

    /// How a note outside the scale is numbered, by semitones above the root.
    public static let chromatic: [Degree] = [
        .init(1), .init(2, -1), .init(2), .init(3, -1), .init(3), .init(4),
        .init(4, 1), .init(5), .init(6, -1), .init(6), .init(7, -1), .init(7),
    ]
}

private func accidentalSymbol(_ accidental: Int) -> String {
    switch accidental {
    case ..<(-1): return "𝄫"
    case -1: return "♭"
    case 1: return "♯"
    case 2...: return "𝄪"
    default: return ""
    }
}

/// A scale or mode. Major and minor are the app's keys; the rest can be chosen as a key too, or
/// saved in a set.
public enum ScaleType: String, Codable, Sendable, CaseIterable, Identifiable {
    case major
    case minor
    case harmonicMinor
    case melodicMinor
    case dorian
    case phrygian
    case lydian
    case mixolydian
    case locrian
    case majorPentatonic
    case minorPentatonic
    case blues
    case wholeTone
    case diminishedWholeHalf
    case diminishedHalfWhole

    public var id: String { rawValue }

    public var degrees: [Degree] {
        switch self {
        case .major: return [.init(1), .init(2), .init(3), .init(4), .init(5), .init(6), .init(7)]
        case .minor: return [.init(1), .init(2), .init(3, -1), .init(4), .init(5), .init(6, -1), .init(7, -1)]
        case .harmonicMinor: return [.init(1), .init(2), .init(3, -1), .init(4), .init(5), .init(6, -1), .init(7)]
        case .melodicMinor: return [.init(1), .init(2), .init(3, -1), .init(4), .init(5), .init(6), .init(7)]
        case .dorian: return [.init(1), .init(2), .init(3, -1), .init(4), .init(5), .init(6), .init(7, -1)]
        case .phrygian: return [.init(1), .init(2, -1), .init(3, -1), .init(4), .init(5), .init(6, -1), .init(7, -1)]
        case .lydian: return [.init(1), .init(2), .init(3), .init(4, 1), .init(5), .init(6), .init(7)]
        case .mixolydian: return [.init(1), .init(2), .init(3), .init(4), .init(5), .init(6), .init(7, -1)]
        case .locrian: return [.init(1), .init(2, -1), .init(3, -1), .init(4), .init(5, -1), .init(6, -1), .init(7, -1)]
        case .majorPentatonic: return [.init(1), .init(2), .init(3), .init(5), .init(6)]
        case .minorPentatonic: return [.init(1), .init(3, -1), .init(4), .init(5), .init(7, -1)]
        case .blues: return [.init(1), .init(3, -1), .init(4), .init(5, -1), .init(5), .init(7, -1)]
        case .wholeTone: return [.init(1), .init(2), .init(3), .init(4, 1), .init(5, 1), .init(7, -1)]
        case .diminishedWholeHalf:
            return [.init(1), .init(2), .init(3, -1), .init(4), .init(5, -1), .init(6, -1), .init(6), .init(7)]
        case .diminishedHalfWhole:
            return [.init(1), .init(2, -1), .init(3, -1), .init(3), .init(4, 1), .init(5), .init(6), .init(7, -1)]
        }
    }

    /// Semitone offsets from the root.
    public var intervals: [Int] { degrees.map(\.semitones) }

    /// e.g. "major", "Dorian", "minor pentatonic".
    public var name: String {
        switch self {
        case .major: return "major"
        case .minor: return "minor"
        case .harmonicMinor: return "harmonic minor"
        case .melodicMinor: return "melodic minor"
        case .dorian: return "Dorian"
        case .phrygian: return "Phrygian"
        case .lydian: return "Lydian"
        case .mixolydian: return "Mixolydian"
        case .locrian: return "Locrian"
        case .majorPentatonic: return "major pentatonic"
        case .minorPentatonic: return "minor pentatonic"
        case .blues: return "blues"
        case .wholeTone: return "whole tone"
        case .diminishedWholeHalf: return "diminished (W–H)"
        case .diminishedHalfWhole: return "diminished (H–W)"
        }
    }

    /// A compact suffix for chips and narrow screens. Ones starting with "m" attach to the root
    /// like a chord symbol ("Am pent."); the rest follow a space ("A Dorian").
    var shortSuffix: String {
        switch self {
        case .harmonicMinor: return "m harm."
        case .melodicMinor: return "m mel."
        case .majorPentatonic: return " pent."
        case .minorPentatonic: return "m pent."
        case .diminishedWholeHalf: return " dim. W–H"
        case .diminishedHalfWhole: return " dim. H–W"
        case .mixolydian: return " Mixo."
        default: return " " + name
        }
    }

    /// Groups for menus and the scale bank.
    public enum Family: String, CaseIterable, Sendable {
        case keys = "Major & Minor"
        case modes = "Modes"
        case other = "Pentatonic & Other"

        public var types: [ScaleType] { ScaleType.allCases.filter { $0.family == self } }
    }

    public var family: Family {
        switch self {
        case .major, .minor, .harmonicMinor, .melodicMinor: return .keys
        case .dorian, .phrygian, .lydian, .mixolydian, .locrian: return .modes
        default: return .other
        }
    }

    /// The key whose sharps or flats spell this scale: modes borrow their parent major key (D
    /// Dorian is spelled like C major); minor-flavored scales use the minor key on their root.
    fileprivate func spellingKey(root: Int) -> (root: Int, isMajor: Bool) {
        switch self {
        case .major, .majorPentatonic, .wholeTone, .diminishedWholeHalf, .diminishedHalfWhole: return (root, true)
        case .minor, .harmonicMinor, .melodicMinor, .minorPentatonic, .blues: return (root, false)
        case .dorian: return (root - 2, true)
        case .phrygian: return (root - 4, true)
        case .lydian: return (root - 5, true)
        case .mixolydian: return (root - 7, true)
        case .locrian: return (root + 1, true)
        }
    }
}

/// A key or scale: a root plus a scale type, e.g. "A minor" or "D Dorian".
public struct MusicalKey: Hashable, Codable, Sendable, Identifiable {
    /// Root pitch class, 0 = C ... 11 = B.
    public var root: Int
    public var type: ScaleType

    public init(root: Int, type: ScaleType) {
        self.root = ((root % 12) + 12) % 12
        self.type = type
    }

    public var id: String { "\(root)-\(type.rawValue)" }

    public static let cMajor = MusicalKey(root: 0, type: .major)

    /// The 24 major and minor keys.
    public static let all: [MusicalKey] =
        (0..<12).map { MusicalKey(root: $0, type: .major) } + (0..<12).map { MusicalKey(root: $0, type: .minor) }

    // Major keys spelled with flats: F, Bb, Eb, Ab, Db, Gb. Minor: their relatives D, G, C, F, Bb, Eb.
    private static let flatMajorRoots: Set<Int> = [5, 10, 3, 8, 1, 6]
    private static let flatMinorRoots: Set<Int> = [2, 7, 0, 5, 10, 3]

    public var usesFlats: Bool {
        let spelling = type.spellingKey(root: root)
        let root = ((spelling.root % 12) + 12) % 12
        return spelling.isMajor ? Self.flatMajorRoots.contains(root) : Self.flatMinorRoots.contains(root)
    }

    public func displayRoot(sharpsOnly: Bool = false) -> String {
        (!sharpsOnly && usesFlats) ? noteNamesFlat[root] : noteNamesSharp[root]
    }

    /// e.g. "Bb major", "D Dorian" or, with `sharpsOnly`, "A# major".
    public func name(sharpsOnly: Bool = false) -> String {
        "\(displayRoot(sharpsOnly: sharpsOnly)) \(type.name)"
    }

    /// e.g. "Am pent." or "D Dorian", for chips and narrow screens.
    public func shortName(sharpsOnly: Bool = false) -> String {
        displayRoot(sharpsOnly: sharpsOnly) + type.shortSuffix
    }

    /// Whether the scale has seven notes, so chords can be built on each degree.
    public var isHeptatonic: Bool { type.degrees.count == 7 }

    /// Pitch classes in the scale, in scale-degree order.
    public var pitchClasses: [Int] { type.intervals.map { (root + $0) % 12 } }

    /// Note names in the scale, spelled for display.
    public func noteNames(sharpsOnly: Bool = false) -> [String] {
        let names = (!sharpsOnly && usesFlats) ? noteNamesFlat : noteNamesSharp
        return pitchClasses.map { names[$0] }
    }

    /// The scale's degree labels, e.g. ["1", "2", "♭3", ...].
    public var degreeLabels: [String] { type.degrees.map(\.label) }

    public func contains(_ note: Note) -> Bool { pitchClasses.contains(note.pitchClass) }

    /// Index of the note in the scale (0 = root), or nil if it's outside the scale.
    public func scaleDegree(of note: Note) -> Int? { pitchClasses.firstIndex(of: note.pitchClass) }

    /// The note's degree: as spelled by the scale when it's in it, otherwise the usual chromatic
    /// spelling (♭2, ♭3, ♯4, ♭6, ♭7).
    public func degree(of note: Note) -> Degree {
        let semitones = (note.pitchClass - root + 12) % 12
        return type.degrees.first { $0.semitones == semitones } ?? Degree.chromatic[semitones]
    }

    /// 0-based index among the semitones outside the scale, or nil if the note is in the scale.
    public func chromaticIndex(of note: Note) -> Int? {
        let semitones = (note.pitchClass - root + 12) % 12
        let inside = type.intervals
        let outside = (0..<12).filter { !inside.contains($0) }
        return outside.firstIndex(of: semitones)
    }

    /// One octave of the scale going up from the root near middle C, ending on the octave.
    public var ascendingNotes: [Note] {
        let start = Note(midi: 48 + root + (root < 5 ? 12 : 0))
        return type.intervals.map { start.transposed(by: $0) } + [start.transposed(by: 12)]
    }
}

/// Note name (no octave) as it should be displayed for the given key and label preference.
public func displayName(for note: Note, key: MusicalKey?, sharpsOnly: Bool) -> String {
    if !sharpsOnly, let key, key.usesFlats {
        return noteNamesFlat[note.pitchClass]
    }
    return note.name
}

/// Returns `true` when `note` should be treated as in key. With no key selected, every note counts.
public func isNote(_ note: Note, inKey key: MusicalKey?) -> Bool {
    key?.contains(note) ?? true
}

/// Names notes by their interval above a chord's root (R, 3, 5, ♭7...), spelled to suit the chord:
/// with a 7th, other notes read as extensions (9, 11, 13); an augmented chord has a ♯5; and so on.
public struct IntervalSpeller: Sendable, Equatable {
    public let root: Int
    /// Semitones above the root present in the chord.
    private let chordTones: Set<Int>

    public init(root: Int, chord: [Note]) {
        let root = ((root % 12) + 12) % 12
        self.root = root
        chordTones = Set(chord.map { ($0.pitchClass - root + 12) % 12 })
    }

    public func label(for note: Note) -> String {
        let semitones = (note.pitchClass - root + 12) % 12
        let has = { self.chordTones.contains($0) }
        let hasThird = has(3) || has(4)
        let hasSeventh = has(10) || has(11)
        // Extensions: a seventh chord, or an add9 (a third plus a 2nd).
        let extended = hasThird && (hasSeventh || has(2))
        switch semitones {
        case 0: return "R"
        case 1: return extended ? "♭9" : "♭2"
        case 2: return extended ? "9" : "2"
        case 3: return has(4) && hasSeventh ? "♯9" : "♭3"
        case 4: return "3"
        case 5: return extended ? "11" : "4"
        case 6: return has(7) && extended ? "♯11" : "♭5"
        case 7: return "5"
        case 8: return has(4) && !has(7) ? "♯5" : (hasSeventh ? "♭13" : "♭6")
        case 9: return has(3) && has(6) && !hasSeventh ? "𝄫7" : (hasSeventh ? "13" : "6")
        case 10: return "♭7"
        default: return "7"
        }
    }
}
