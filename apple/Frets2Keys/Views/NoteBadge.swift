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

/// The colored square drawn on a fret or piano key.
struct NoteBadge: View {
    @Environment(\.theme) private var theme
    let appearance: NoteAppearance
    let selectedSize: CGFloat
    let unselectedSize: CGFloat
    /// Text color for plain (uncolored) labels.
    var plainTextColor: Color?

    var body: some View {
        let size = appearance.isSelected ? selectedSize : unselectedSize
        NoteLabel(name: appearance.label, weight: appearance.isSelected ? .medium : .regular)
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(background, in: RoundedRectangle(cornerRadius: 4))
            .overlay {
                if case .inKey(let degree) = appearance.style {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(ScaleDegreePalette.all[degree].border(dark: theme.isDark), lineWidth: 1)
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
