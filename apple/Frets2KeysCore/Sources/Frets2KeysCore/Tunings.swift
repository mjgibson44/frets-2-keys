import Foundation

/// Tunings are listed from the lowest-pitched string to the highest.
public enum Tunings {
    public static let standard: [Note] = ["E2", "A2", "D3", "G3", "B3", "E4"]

    public static let minStrings = 4
    public static let maxStrings = 8
    public static let maxCapo = 12
    public static let fretCount = 24

    private static let defaults: [Int: [Note]] = [
        4: ["E1", "A1", "D2", "G2"],                          // Bass guitar
        5: ["B0", "E1", "A1", "D2", "G2"],                    // 5-string bass
        6: ["E2", "A2", "D3", "G3", "B3", "E4"],              // Standard guitar
        7: ["B1", "E2", "A2", "D3", "G3", "B3", "E4"],        // 7-string guitar
        8: ["F#1", "B1", "E2", "A2", "D3", "G3", "B3", "E4"], // 8-string guitar
    ]

    public static func defaultTuning(stringCount: Int) -> [Note] {
        defaults[stringCount] ?? standard
    }

    /// Label for a string in the settings editor. Strings are numbered from the highest pitch (1).
    public static func stringLabel(number: Int, totalStrings: Int) -> String {
        let standard6 = [1: "1 (High E)", 2: "2 (B)", 3: "3 (G)", 4: "4 (D)", 5: "5 (A)", 6: "6 (Low E)"]
        if totalStrings == 6, let label = standard6[number] { return label }
        return "String \(number)"
    }
}

public struct TuningPreset: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let category: String
    public let tuning: [Note]

    public static let all: [TuningPreset] = [
        // Guitar - 6 string
        .init(id: "guitar-standard", name: "Standard", category: "Guitar (6 string)", tuning: ["E2", "A2", "D3", "G3", "B3", "E4"]),
        .init(id: "guitar-drop-d", name: "Drop D", category: "Guitar (6 string)", tuning: ["D2", "A2", "D3", "G3", "B3", "E4"]),
        .init(id: "guitar-drop-c", name: "Drop C", category: "Guitar (6 string)", tuning: ["C2", "G2", "C3", "F3", "A3", "D4"]),
        .init(id: "guitar-open-g", name: "Open G", category: "Guitar (6 string)", tuning: ["D2", "G2", "D3", "G3", "B3", "D4"]),
        .init(id: "guitar-open-d", name: "Open D", category: "Guitar (6 string)", tuning: ["D2", "A2", "D3", "F#3", "A3", "D4"]),
        .init(id: "guitar-open-e", name: "Open E", category: "Guitar (6 string)", tuning: ["E2", "B2", "E3", "G#3", "B3", "E4"]),
        .init(id: "guitar-dadgad", name: "DADGAD", category: "Guitar (6 string)", tuning: ["D2", "A2", "D3", "G3", "A3", "D4"]),
        .init(id: "guitar-half-step-down", name: "Half Step Down", category: "Guitar (6 string)", tuning: ["D#2", "G#2", "C#3", "F#3", "A#3", "D#4"]),
        .init(id: "guitar-full-step-down", name: "Full Step Down", category: "Guitar (6 string)", tuning: ["D2", "G2", "C3", "F3", "A3", "D4"]),

        // Guitar - 7 string
        .init(id: "guitar-7-standard", name: "Standard", category: "Guitar (7 string)", tuning: ["B1", "E2", "A2", "D3", "G3", "B3", "E4"]),
        .init(id: "guitar-7-drop-a", name: "Drop A", category: "Guitar (7 string)", tuning: ["A1", "E2", "A2", "D3", "G3", "B3", "E4"]),

        // Guitar - 8 string
        .init(id: "guitar-8-standard", name: "Standard", category: "Guitar (8 string)", tuning: ["F#1", "B1", "E2", "A2", "D3", "G3", "B3", "E4"]),
        .init(id: "guitar-8-drop-e", name: "Drop E", category: "Guitar (8 string)", tuning: ["E1", "B1", "E2", "A2", "D3", "G3", "B3", "E4"]),

        // Bass - 4 string
        .init(id: "bass-4-standard", name: "Standard", category: "Bass (4 string)", tuning: ["E1", "A1", "D2", "G2"]),
        .init(id: "bass-4-drop-d", name: "Drop D", category: "Bass (4 string)", tuning: ["D1", "A1", "D2", "G2"]),
        .init(id: "bass-4-half-step-down", name: "Half Step Down", category: "Bass (4 string)", tuning: ["D#1", "G#1", "C#2", "F#2"]),

        // Bass - 5 string
        .init(id: "bass-5-standard", name: "Standard", category: "Bass (5 string)", tuning: ["B0", "E1", "A1", "D2", "G2"]),
        .init(id: "bass-5-tenor", name: "Tenor (High C)", category: "Bass (5 string)", tuning: ["E1", "A1", "D2", "G2", "C3"]),

        // Bass - 6 string
        .init(id: "bass-6-standard", name: "Standard", category: "Bass (6 string)", tuning: ["B0", "E1", "A1", "D2", "G2", "C3"]),

        // Ukulele
        .init(id: "ukulele-soprano", name: "Soprano/Concert/Tenor", category: "Ukulele", tuning: ["G4", "C4", "E4", "A4"]),
        .init(id: "ukulele-baritone", name: "Baritone", category: "Ukulele", tuning: ["D3", "G3", "B3", "E4"]),
        .init(id: "ukulele-low-g", name: "Low G", category: "Ukulele", tuning: ["G3", "C4", "E4", "A4"]),

        // Mandolin
        .init(id: "mandolin-standard", name: "Standard", category: "Mandolin", tuning: ["G3", "D4", "A4", "E5"]),

        // Banjo
        .init(id: "banjo-open-g", name: "Open G", category: "Banjo (5 string)", tuning: ["G4", "D3", "G3", "B3", "D4"]),
        .init(id: "banjo-standard-c", name: "Standard C", category: "Banjo (5 string)", tuning: ["G4", "C3", "G3", "B3", "D4"]),
    ]

    /// Category names in display order.
    public static var categories: [String] {
        var seen = Set<String>()
        return all.map(\.category).filter { seen.insert($0).inserted }
    }

    public static func matching(_ tuning: [Note]) -> TuningPreset? {
        all.first { $0.tuning == tuning }
    }
}
