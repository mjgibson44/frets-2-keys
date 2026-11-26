import SwiftUI
import Frets2KeysCore

/// A note name with a small raised accidental, e.g. "B♭" drawn as "B" + small "b". Degrees and
/// intervals put theirs first: "♭3" is a small "♭" + "3".
struct NoteLabel: View {
    let name: String
    var fontSize: CGFloat = 12
    var weight: Font.Weight = .regular

    private static let leadingAccidentals: Set<Character> = ["♭", "♯", "𝄫", "𝄪"]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if let first = name.first, Self.leadingAccidentals.contains(first), name.count > 1 {
                small(String(first))
                main(String(name.dropFirst()))
            } else if name.allSatisfy(\.isNumber) {
                // A plain number ("11", "13") is one piece, not a letter and an accidental.
                main(name)
            } else {
                let parts = splitNoteDisplay(name)
                main(parts.letter)
                if let accidental = parts.accidental {
                    small(accidental)
                }
            }
        }
        .fixedSize()
    }

    private func main(_ text: String) -> some View {
        // Two-digit intervals (11, 13) are a touch smaller to fit the badge.
        Text(text).font(.system(size: text.count > 1 && text.allSatisfy(\.isNumber) ? fontSize - 1 : fontSize, weight: weight))
    }

    private func small(_ text: String) -> some View {
        Text(text).font(.system(size: 8, weight: weight))
    }
}

/// A chord name as shown: a plain major triad drops its "maj" ("Dmaj" → "D", "Dmaj/F#" → "D/F#"),
/// while "maj7", "maj9" and so on keep it, since D7 and Dmaj7 are different chords.
func chordDisplayName(_ name: String) -> String {
    name.replacingOccurrences(of: #"maj(?=$|[/*\s(])"#, with: "", options: .regularExpression)
}

/// Text with each accidental (♯, ♭, #, or a "b" right after a note letter) drawn small and raised,
/// like the instruments' note labels: "F#m7", "B♭ major", "m7♭5". It's a plain `Text`, so line
/// limits and colors apply as usual; the size and weight are set here rather than with `.font`.
func noteText(_ string: String, size: CGFloat, weight: Font.Weight = .regular) -> Text {
    var segments: [(text: String, isAccidental: Bool)] = []
    var previous: Character?
    for character in string {
        let isAccidental = "♯♭𝄪𝄫#".contains(character)
            || (character == "b" && previous.map { "ABCDEFG".contains($0) } == true)
        if let last = segments.last, last.isAccidental == isAccidental {
            segments[segments.count - 1].text.append(character)
        } else {
            segments.append((String(character), isAccidental))
        }
        previous = character
    }
    return segments.reduce(Text(verbatim: "")) { text, segment in
        segment.isAccidental
            ? text + Text(verbatim: segment.text).font(.system(size: (size * 0.62).rounded(), weight: weight)).baselineOffset(size * 0.38)
            : text + Text(verbatim: segment.text).font(.system(size: size, weight: weight))
    }
}

extension NoteLabelContext {
    /// Spoken name for a note: "Bb3", plus its degree or interval when those are showing.
    func accessibilityName(for note: Note) -> String {
        let name = displayName(for: note, key: key, sharpsOnly: noteLabelMode == .sharpsOnly)
        let label = label(for: note)
        return label == name ? "\(name)\(note.octave)" : "\(name)\(note.octave), \(label)"
    }
}

/// The colored square drawn on a fret or piano key. Selecting a note fills it in; it stays the
/// same size.
struct NoteBadge: View {
    @Environment(\.theme) private var theme
    let appearance: NoteAppearance
    let size: CGFloat
    /// Text color for plain (uncolored) labels.
    var plainTextColor: Color?

    var body: some View {
        NoteLabel(name: appearance.label, weight: appearance.isSelected ? .medium : .regular)
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(background, in: RoundedRectangle(cornerRadius: 4))
            .overlay {
                // A soft edge, lighter than the full scale-degree border. Dark mode shows just the tint.
                if case .inKey(let degree) = appearance.style, !theme.isDark {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(ScaleDegreePalette.all[degree].border(dark: theme.isDark).opacity(0.4), lineWidth: 1)
                }
            }
            .opacity(appearance.isDimmed ? (theme.isDark ? 0.18 : 0.3) : 1)
    }

    private var foreground: Color {
        switch appearance.style {
        case .selected(let role): return theme.noteSolidText(role)
        case .inKey(let degree): return theme.isDark ? ScaleDegreePalette.all[degree].darkText : Tailwind.zinc700
        case .plain: return plainTextColor ?? theme.plainNoteText
        }
    }

    private var background: Color {
        switch appearance.style {
        case .selected(let role): return theme.noteSolid(role)
        case .inKey(let degree): return ScaleDegreePalette.all[degree].tint(dark: theme.isDark)
        case .plain: return .clear
        }
    }
}

/// Colors a tile or chip the way the instruments color notes: in-key notes get their scale-degree
/// tint and border, other notes a light wash of their color, and a selected one is solid with
/// white text.
struct NoteTileStyle: ViewModifier {
    @Environment(\.theme) private var theme
    let role: NoteColorRole?
    let isSelected: Bool
    var selectedColor: Color = .accentColor
    var selectedTextColor: Color = .white
    /// Tiles in a grid stretch to their column; chips keep their natural width.
    var fillsWidth = true
    var minHeight: CGFloat = 0
    var cornerRadius: CGFloat = 6
    /// Border for an uncolored, unselected tile (chips on the page need one to stand out).
    var neutralBorder: Color = .clear
    /// Whether a colored tile gets a matching border, or just the tinted background.
    var showsColorBorder = true
    var neutralFill: Color?

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        content
            .foregroundStyle(foreground)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: minHeight)
            .background(fill, in: shape)
            .overlay {
                if !isSelected {
                    shape.strokeBorder(border, lineWidth: 1)
                }
            }
            .contentShape(shape)
    }

    /// Selected: the same text as a selected note (or `selectedTextColor` for a neutral tile).
    /// Unselected and colored, dark mode tints the text like the instruments' notes.
    private var foreground: Color {
        if isSelected { return role.map(theme.noteSolidText) ?? selectedTextColor }
        if theme.isDark, let role { return theme.noteSolidText(role) }
        return theme.secondaryText
    }

    private var fill: Color {
        if isSelected { return role.map(theme.noteSolid) ?? selectedColor }
        return role.map { NotePalette.tint(for: $0, dark: theme.isDark) } ?? neutralFill ?? theme.chip
    }

    private var border: Color {
        if role != nil && !showsColorBorder { return .clear }
        switch role {
        case .scaleDegree(let degree)?: return ScaleDegreePalette.all[degree].border(dark: theme.isDark)
        case let role?: return theme.noteSolid(role).opacity(theme.isDark ? 0.7 : 0.55)
        case nil: return neutralBorder
        }
    }
}

/// While a note sounds during playback, its fret or piano key briefly shades: darker in light mode,
/// slightly lighter in dark mode. It snaps on and off. Apply it inside any fill it should shade.
struct NoteFlash: ViewModifier {
    @Environment(\.theme) private var theme
    let isFlashing: Bool
    /// Fret cells shade the same inset rounded square a selected fret is filled with.
    var inset: CGFloat = 0
    var horizontalInset: CGFloat?
    var cornerRadius: CGFloat = 0

    func body(content: Content) -> some View {
        // Behind the content, so the note's label stays crisp on top of the shade.
        content
            .background {
                InsetRoundedRectangle(cornerRadius: cornerRadius, dx: horizontalInset ?? inset, dy: inset)
                    .fill(theme.isDark ? Color.white : Color.black)
                    .opacity(isFlashing ? (theme.isDark ? 0.15 : 0.32) : 0)
                    // Instant both ways, so one note's shade doesn't linger into the next.
                    .transaction { $0.animation = nil }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }
}

extension View {
    func noteFlash(_ isFlashing: Bool, inset: CGFloat = 0, horizontalInset: CGFloat? = nil, cornerRadius: CGFloat = 0) -> some View {
        modifier(NoteFlash(isFlashing: isFlashing, inset: inset, horizontalInset: horizontalInset, cornerRadius: cornerRadius))
    }
}
