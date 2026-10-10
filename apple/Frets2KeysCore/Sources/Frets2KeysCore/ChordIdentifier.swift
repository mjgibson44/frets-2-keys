import Foundation

/// Names a set of notes as a chord (e.g. "Cmaj", "Am7/G", "G7*"), mirroring the web app's rules.
public enum ChordIdentifier {
    struct Pattern {
        let name: String
        /// Pitch-class intervals from the root, deduplicated and sorted.
        let intervals: [Int]

        init(_ name: String, _ intervals: [Int]) {
            self.name = name
            self.intervals = Array(Set(intervals.map { (($0 % 12) + 12) % 12 })).sorted()
        }
    }

    // Order matters: the first exact match wins.
    static let patterns: [Pattern] = [
        // Triads
        .init("maj", [0, 4, 7]),
        .init("m", [0, 3, 7]),
        .init("dim", [0, 3, 6]),
        .init("aug", [0, 4, 8]),
        .init("sus2", [0, 2, 7]),
        .init("sus4", [0, 5, 7]),

        // Seventh chords
        .init("maj7", [0, 4, 7, 11]),
        .init("7", [0, 4, 7, 10]),
        .init("m7", [0, 3, 7, 10]),
        .init("mMaj7", [0, 3, 7, 11]),
        .init("dim7", [0, 3, 6, 9]),
        .init("m7b5", [0, 3, 6, 10]),
        .init("aug7", [0, 4, 8, 10]),
        .init("augMaj7", [0, 4, 8, 11]),
        .init("7sus4", [0, 5, 7, 10]),
        .init("7sus2", [0, 2, 7, 10]),
        .init("maj7sus4", [0, 5, 7, 11]),
        .init("maj7sus2", [0, 2, 7, 11]),

        // Sixth chords
        .init("6", [0, 4, 7, 9]),
        .init("m6", [0, 3, 7, 9]),
        .init("6/9", [0, 4, 7, 9, 2]),
        .init("m6/9", [0, 3, 7, 9, 2]),

        // Ninth chords
        .init("9", [0, 4, 7, 10, 2]),
        .init("maj9", [0, 4, 7, 11, 2]),
        .init("m9", [0, 3, 7, 10, 2]),
        .init("mMaj9", [0, 3, 7, 11, 2]),
        .init("9sus4", [0, 5, 7, 10, 2]),
        .init("add9", [0, 4, 7, 2]),
        .init("madd9", [0, 3, 7, 2]),
        .init("7b9", [0, 4, 7, 10, 1]),
        .init("7#9", [0, 4, 7, 10, 3]),
        .init("maj7#9", [0, 4, 7, 11, 3]),

        // Eleventh chords
        .init("11", [0, 4, 7, 10, 2, 5]),
        .init("maj11", [0, 4, 7, 11, 2, 5]),
        .init("m11", [0, 3, 7, 10, 2, 5]),
        .init("7#11", [0, 4, 7, 10, 6]),
        .init("maj7#11", [0, 4, 7, 11, 6]),
        .init("add11", [0, 4, 7, 5]),
        .init("madd11", [0, 3, 7, 5]),
        // Partial 11ths (no 9th)
        .init("11", [0, 4, 7, 10, 5]),
        .init("m11", [0, 3, 7, 10, 5]),
        .init("maj11", [0, 4, 7, 11, 5]),

        // Thirteenth chords
        .init("13", [0, 4, 7, 10, 2, 9]),
        .init("maj13", [0, 4, 7, 11, 2, 9]),
        .init("m13", [0, 3, 7, 10, 2, 9]),
        .init("13sus4", [0, 5, 7, 10, 2, 9]),
        // Partial 13ths (no 9th or 11th)
        .init("13", [0, 4, 7, 10, 9]),
        .init("maj13", [0, 4, 7, 11, 9]),
        .init("m13", [0, 3, 7, 10, 9]),
        .init("7add13", [0, 4, 7, 10, 9]),

        // Altered chords
        .init("7b5", [0, 4, 6, 10]),
        .init("7#5", [0, 4, 8, 10]),
        .init("maj7b5", [0, 4, 6, 11]),
        .init("maj7#5", [0, 4, 8, 11]),
        .init("7b5b9", [0, 4, 6, 10, 1]),
        .init("7#5#9", [0, 4, 8, 10, 3]),
        .init("7alt", [0, 4, 6, 10, 1]),
        .init("7b9b5", [0, 4, 6, 10, 1]),
        .init("7#9#5", [0, 4, 8, 10, 3]),

        // Add chords
        .init("add4", [0, 4, 5, 7]),
        .init("madd4", [0, 3, 5, 7]),
        .init("add2", [0, 2, 4, 7]),
        .init("madd2", [0, 2, 3, 7]),

        // Shell voicings: no 5th
        .init("maj7", [0, 4, 11]),
        .init("7", [0, 4, 10]),
        .init("m7", [0, 3, 10]),
        .init("mMaj7", [0, 3, 11]),
        // No 3rd
        .init("7sus", [0, 7, 10]),
        .init("maj7sus", [0, 7, 11]),
        // Root + 7th only
        .init("maj7", [0, 11]),
        .init("7", [0, 10]),

        // Quartal
        .init("quartal", [0, 5, 10]),
        .init("quartal", [0, 5, 10, 3]),

        // Power chord
        .init("5", [0, 7]),

        // Intervals
        .init(" (octave)", [0]),
        .init(" (min 2nd)", [0, 1]),
        .init(" (maj 2nd)", [0, 2]),
        .init(" (min 3rd)", [0, 3]),
        .init(" (maj 3rd)", [0, 4]),
        .init(" (4th)", [0, 5]),
        .init(" (tritone)", [0, 6]),
        .init(" (5th)", [0, 7]),
        .init(" (min 6th)", [0, 8]),
        .init(" (maj 6th)", [0, 9]),
        .init(" (min 7th)", [0, 10]),
        .init(" (maj 7th)", [0, 11]),
    ]

    private static func intervals(of notes: [Note], from root: Note) -> [Int] {
        let pitchClasses: Set<Int> = Set(notes.map { (note: Note) -> Int in
            let distance = note.midi - root.midi
            return ((distance % 12) + 12) % 12
        })
        return pitchClasses.sorted()
    }

    private static func exactMatch(_ intervals: [Int]) -> Pattern? {
        patterns.first { $0.intervals == intervals }
    }

    /// Best pattern whose intervals are all present, preferring the most complete match.
    private static func subsetMatch(_ intervals: [Int]) -> Pattern? {
        var best: Pattern?
        var bestScore = 0
        let available = Set(intervals)
        for pattern in patterns {
            if pattern.intervals.count > intervals.count { continue }
            // Plain intervals aren't meaningful once there are 3+ distinct pitches.
            if pattern.intervals.count <= 2 && intervals.count > 2 { continue }
            guard pattern.intervals.allSatisfy(available.contains) else { continue }
            let score = pattern.intervals.count * 10 - (intervals.count - pattern.intervals.count)
            if score > bestScore {
                bestScore = score
                best = pattern
            }
        }
        return best
    }

    public static func identify(_ notes: [Note]) -> String? {
        guard let first = notes.first else { return nil }
        if notes.count == 1 { return first.name }

        let sorted = notes.sorted()
        let bass = sorted[0]
        if Set(sorted.map(\.pitchClass)).count == 1 { return bass.name }

        func name(root: Note, pattern: Pattern, suffix: String = "") -> String {
            let chord = "\(root.name)\(pattern.name)\(suffix)"
            return bass.name == root.name ? chord : "\(chord)/\(bass.name)"
        }

        // Exact match, trying each note as the root from the bass up.
        for root in sorted {
            if let pattern = exactMatch(intervals(of: sorted, from: root)) {
                return name(root: root, pattern: pattern)
            }
        }

        // Subset match: a known chord plus extra notes, flagged with "*".
        for root in sorted {
            let rootIntervals = intervals(of: sorted, from: root)
            if let pattern = subsetMatch(rootIntervals) {
                let suffix = rootIntervals.count > pattern.intervals.count ? "*" : ""
                return name(root: root, pattern: pattern, suffix: suffix)
            }
        }

        let fromBass = intervals(of: sorted, from: bass)
        let hasThird = fromBass.contains(3) || fromBass.contains(4)
        let hasFifth = fromBass.contains(6) || fromBass.contains(7) || fromBass.contains(8)
        if hasThird && hasFifth { return "\(bass.name)?" }
        return "\(bass.name) (unrecognized)"
    }
}
