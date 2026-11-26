import Foundation

/// A well-known song's chord progression, section by section, to copy into the library as a
/// starting point. Progressions are the common, simplified versions (no lyrics).
public struct PresetSong: Identifiable, Hashable, Sendable {
    public struct Section: Hashable, Sendable {
        public let name: String
        /// Root pitch class (0 = C) and `ChordQuality` id, in playing order.
        public let chords: [Chord]
    }

    public struct Chord: Hashable, Sendable {
        public let root: Int
        public let quality: String
    }

    public let title: String
    public let artist: String
    public let sections: [Section]

    public var id: String { title }

    /// A new song with this progression (fresh IDs, so it can be copied more than once).
    public func makeSong() -> ChordSet {
        ChordSet(name: title, sections: sections.map { section in
            ChordSection(name: section.name, chords: section.chords.compactMap { chord in
                guard let quality = ChordBank.qualities.first(where: { $0.id == chord.quality }) else { return nil }
                return SavedChord(
                    name: ChordBank.name(root: chord.root, quality: quality),
                    notes: ChordBank.notes(root: chord.root, quality: quality)
                )
            })
        })
    }
}

/// Popular songs to start from, picked from the song menu.
public enum SongBank {
    // Pitch classes, for readability below.
    private static let C = 0, D = 2, E = 4, F = 5, Fs = 6, G = 7, A = 9

    private static func chords(_ list: [(Int, String)]) -> [PresetSong.Chord] {
        list.map { PresetSong.Chord(root: $0.0, quality: $0.1) }
    }

    public static let songs: [PresetSong] = [
        PresetSong(title: "Let It Be", artist: "The Beatles", sections: [
            .init(name: "Verse", chords: chords([(C, "maj"), (G, "maj"), (A, "m"), (F, "maj"), (C, "maj"), (G, "maj"), (F, "maj"), (C, "maj")])),
            .init(name: "Chorus", chords: chords([(A, "m"), (G, "maj"), (F, "maj"), (C, "maj"), (C, "maj"), (G, "maj"), (F, "maj"), (C, "maj")])),
        ]),
        PresetSong(title: "Stand By Me", artist: "Ben E. King", sections: [
            .init(name: "Verse", chords: chords([(A, "maj"), (A, "maj"), (Fs, "m"), (Fs, "m"), (D, "maj"), (E, "maj"), (A, "maj"), (A, "maj")])),
            .init(name: "Chorus", chords: chords([(A, "maj"), (Fs, "m"), (D, "maj"), (E, "maj"), (A, "maj")])),
        ]),
        PresetSong(title: "Knockin' on Heaven's Door", artist: "Bob Dylan", sections: [
            .init(name: "Verse", chords: chords([(G, "maj"), (D, "maj"), (A, "m"), (A, "m"), (G, "maj"), (D, "maj"), (C, "maj"), (C, "maj")])),
            .init(name: "Chorus", chords: chords([(G, "maj"), (D, "maj"), (A, "m"), (A, "m"), (G, "maj"), (D, "maj"), (C, "maj"), (C, "maj")])),
        ]),
        PresetSong(title: "Hallelujah", artist: "Leonard Cohen", sections: [
            .init(name: "Verse", chords: chords([(C, "maj"), (A, "m"), (C, "maj"), (A, "m"), (F, "maj"), (G, "maj"), (C, "maj"), (G, "maj"),
                                                 (C, "maj"), (F, "maj"), (G, "maj"), (A, "m"), (F, "maj"), (G, "maj"), (E, "7"), (A, "m")])),
            .init(name: "Chorus", chords: chords([(F, "maj"), (A, "m"), (F, "maj"), (C, "maj"), (G, "maj"), (C, "maj")])),
        ]),
        PresetSong(title: "House of the Rising Sun", artist: "Traditional", sections: [
            .init(name: "Verse", chords: chords([(A, "m"), (C, "maj"), (D, "maj"), (F, "maj"), (A, "m"), (C, "maj"), (E, "maj"), (E, "maj"),
                                                 (A, "m"), (C, "maj"), (D, "maj"), (F, "maj"), (A, "m"), (E, "maj"), (A, "m"), (E, "maj")])),
        ]),
    ]
}

