import SwiftUI
import Frets2KeysCore

/// A note name with a small raised accidental, e.g. "B♭" drawn as "B" + small "b".
struct NoteLabel: View {
    let name: String
    var fontSize: CGFloat = 12
    var weight: Font.Weight = .regular

    var body: some View {
        let parts = splitNoteDisplay(name)
        HStack(alignment: .top, spacing: 0) {
            Text(parts.letter)
                .font(.system(size: fontSize, weight: weight))
            if let accidental = parts.accidental {
                Text(accidental)
                    .font(.system(size: 8, weight: weight))
            }
        }
        .fixedSize()
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
