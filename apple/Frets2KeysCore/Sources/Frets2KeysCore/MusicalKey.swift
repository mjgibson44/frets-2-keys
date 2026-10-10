import Foundation

public enum KeyType: String, Codable, Sendable, CaseIterable {
    case major
    case minor

    /// Semitone offsets from the root.
    public var intervals: [Int] {
        switch self {
        case .major: return [0, 2, 4, 5, 7, 9, 11]
        case .minor: return [0, 2, 3, 5, 7, 8, 10]
        }
    }
}

public struct MusicalKey: Hashable, Codable, Sendable, Identifiable {
    /// Root pitch class, 0 = C ... 11 = B.
    public var root: Int
    public var type: KeyType

    public init(root: Int, type: KeyType) {
        self.root = ((root % 12) + 12) % 12
        self.type = type
    }

    public var id: String { "\(root)-\(type.rawValue)" }

    public static let cMajor = MusicalKey(root: 0, type: .major)

    public static let all: [MusicalKey] =
        (0..<12).map { MusicalKey(root: $0, type: .major) } + (0..<12).map { MusicalKey(root: $0, type: .minor) }

    // Major keys spelled with flats: F, Bb, Eb, Ab, Db, Gb. Minor: their relatives D, G, C, F, Bb, Eb.
    private static let flatMajorRoots: Set<Int> = [5, 10, 3, 8, 1, 6]
    private static let flatMinorRoots: Set<Int> = [2, 7, 0, 5, 10, 3]

    public var usesFlats: Bool {
        switch type {
        case .major: return Self.flatMajorRoots.contains(root)
        case .minor: return Self.flatMinorRoots.contains(root)
        }
    }

    public func displayRoot(sharpsOnly: Bool = false) -> String {
        (!sharpsOnly && usesFlats) ? noteNamesFlat[root] : noteNamesSharp[root]
    }

    /// e.g. "Bb major" or, with `sharpsOnly`, "A# major".
    public func name(sharpsOnly: Bool = false) -> String {
        "\(displayRoot(sharpsOnly: sharpsOnly)) \(type.rawValue)"
    }

    /// Pitch classes in the scale, in scale-degree order.
    public var pitchClasses: [Int] { type.intervals.map { (root + $0) % 12 } }

    /// Note names in the scale, spelled for display.
    public func noteNames(sharpsOnly: Bool = false) -> [String] {
        let names = (!sharpsOnly && usesFlats) ? noteNamesFlat : noteNamesSharp
        return pitchClasses.map { names[$0] }
    }

    public func contains(_ note: Note) -> Bool { pitchClasses.contains(note.pitchClass) }

    /// 0-6 scale degree of the note, or nil if it's outside the key.
    public func scaleDegree(of note: Note) -> Int? { pitchClasses.firstIndex(of: note.pitchClass) }

    /// 0-4 index among the five chromatic (out-of-key) semitones, or nil if the note is in the key.
    public func chromaticIndex(of note: Note) -> Int? {
        let semitones = (note.pitchClass - root + 12) % 12
        let outside = (0..<12).filter { !type.intervals.contains($0) }
        return outside.firstIndex(of: semitones)
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
