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
                // A soft edge, lighter than the full scale-degree border.
                if case .inKey(let degree) = appearance.style {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(ScaleDegreePalette.all[degree].border(dark: theme.isDark).opacity(0.4), lineWidth: 1)
                }
            }
            .opacity(appearance.isDimmed ? 0.3 : 1)
    }

    private var foreground: Color {
        switch appearance.style {
        case .selected: return .white
        case .inKey: return theme.isDark ? Tailwind.zinc200 : Tailwind.zinc700
        case .plain: return plainTextColor ?? theme.plainNoteText
        }
    }

    private var background: Color {
        switch appearance.style {
        case .selected(let role): return NotePalette.solid(for: role)
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
            .foregroundStyle(isSelected ? .white : theme.secondaryText)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: minHeight)
            .background(fill, in: shape)
            .overlay {
                if !isSelected {
                    shape.strokeBorder(border, lineWidth: 1)
                }
            }
            .contentShape(shape)
    }

    private var fill: Color {
        if isSelected { return role.map(NotePalette.solid(for:)) ?? selectedColor }
        return role.map { NotePalette.tint(for: $0, dark: theme.isDark) } ?? neutralFill ?? theme.chip
    }

    private var border: Color {
        if role != nil && !showsColorBorder { return .clear }
        switch role {
        case .scaleDegree(let degree)?: return ScaleDegreePalette.all[degree].border(dark: theme.isDark)
        case let role?: return NotePalette.solid(for: role).opacity(theme.isDark ? 0.7 : 0.55)
        case nil: return neutralBorder
        }
    }
}
