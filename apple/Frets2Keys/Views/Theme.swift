import SwiftUI
import Frets2KeysCore

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Tailwind shades used by the web app.
enum Tailwind {
    static let zinc100 = Color(hex: 0xF4F4F5)
    static let zinc200 = Color(hex: 0xE4E4E7)
    static let zinc300 = Color(hex: 0xD4D4D8)
    static let zinc400 = Color(hex: 0xA1A1AA)
    static let zinc500 = Color(hex: 0x71717A)
    static let zinc600 = Color(hex: 0x52525B)
    static let zinc700 = Color(hex: 0x3F3F46)
    static let zinc800 = Color(hex: 0x27272A)
    static let zinc900 = Color(hex: 0x18181B)
    static let amber500 = Color(hex: 0xF59E0B)
    static let amber600 = Color(hex: 0xD97706)
    static let green500 = Color(hex: 0x22C55E)
    static let blue500 = Color(hex: 0x3B82F6)
}

/// Colors for the 7 scale degrees: tinted (unselected, in key), solid (selected) and border.
struct ScaleDegreePalette {
    let light100: Color
    let solid: Color
    let lightBorder: Color
    let dark900: Color
    let darkBorder: Color

    func tint(dark: Bool) -> Color { dark ? dark900.opacity(0.4) : light100 }
    func border(dark: Bool) -> Color { dark ? darkBorder : lightBorder }

    static let all: [ScaleDegreePalette] = [
        // red, orange, yellow, green, cyan, blue, purple
        .init(light100: Color(hex: 0xFEE2E2), solid: Color(hex: 0xEF4444), lightBorder: Color(hex: 0xF87171), dark900: Color(hex: 0x7F1D1D), darkBorder: Color(hex: 0xB91C1C)),
        .init(light100: Color(hex: 0xFFEDD5), solid: Color(hex: 0xEA580C), lightBorder: Color(hex: 0xFB923C), dark900: Color(hex: 0x7C2D12), darkBorder: Color(hex: 0xC2410C)),
        .init(light100: Color(hex: 0xFEF9C3), solid: Color(hex: 0xCA8A04), lightBorder: Color(hex: 0xFACC15), dark900: Color(hex: 0x713F12), darkBorder: Color(hex: 0xA16207)),
        .init(light100: Color(hex: 0xDCFCE7), solid: Color(hex: 0x16A34A), lightBorder: Color(hex: 0x4ADE80), dark900: Color(hex: 0x14532D), darkBorder: Color(hex: 0x15803D)),
        .init(light100: Color(hex: 0xCFFAFE), solid: Color(hex: 0x0891B2), lightBorder: Color(hex: 0x22D3EE), dark900: Color(hex: 0x164E63), darkBorder: Color(hex: 0x0E7490)),
        .init(light100: Color(hex: 0xDBEAFE), solid: Color(hex: 0x3B82F6), lightBorder: Color(hex: 0x60A5FA), dark900: Color(hex: 0x1E3A8A), darkBorder: Color(hex: 0x1D4ED8)),
        .init(light100: Color(hex: 0xF3E8FF), solid: Color(hex: 0xA855F7), lightBorder: Color(hex: 0xC084FC), dark900: Color(hex: 0x581C87), darkBorder: Color(hex: 0x7E22CE)),
    ]
}

enum NotePalette {
    // pink, lime, teal, indigo, rose
    static let outOfKey: [Color] = [
        Color(hex: 0xEC4899), Color(hex: 0x65A30D), Color(hex: 0x0D9488), Color(hex: 0x6366F1), Color(hex: 0xF43F5E),
    ]

    // One color per pitch class, C through B, used when no key is selected.
    static let chromatic: [Color] = [
        Color(hex: 0xEF4444), // C  red
        Color(hex: 0xEC4899), // C# pink
        Color(hex: 0xEA580C), // D  orange
        Color(hex: 0x65A30D), // D# lime
        Color(hex: 0xCA8A04), // E  yellow
        Color(hex: 0x16A34A), // F  green
        Color(hex: 0x0D9488), // F# teal
        Color(hex: 0x0891B2), // G  cyan
        Color(hex: 0x6366F1), // G# indigo
        Color(hex: 0x3B82F6), // A  blue
        Color(hex: 0xF43F5E), // A# rose
        Color(hex: 0xA855F7), // B  purple
    ]

    static func solid(for role: NoteColorRole) -> Color {
        switch role {
        case .scaleDegree(let degree): return ScaleDegreePalette.all[degree].solid
        case .outOfKey(let index): return outOfKey[index]
        case .chromatic(let pitchClass): return chromatic[pitchClass]
        }
    }
}

/// Surface and text colors for light and dark mode.
struct Theme {
    let isDark: Bool

    var pageBackground: Color { isDark ? Tailwind.zinc900 : Color(hex: 0xF8F4F4) }
    var cardBackground: Color { isDark ? Tailwind.zinc800 : .white }
    var cardBorder: Color { isDark ? Tailwind.zinc700 : Color(hex: 0xEDE9E9) }
    var primaryText: Color { isDark ? Tailwind.zinc100 : Tailwind.zinc900 }
    var secondaryText: Color { isDark ? Tailwind.zinc200 : Tailwind.zinc700 }
    var mutedText: Color { isDark ? Tailwind.zinc500 : Tailwind.zinc400 }
    var icon: Color { isDark ? Tailwind.zinc400 : Tailwind.zinc500 }
    var iconDisabled: Color { isDark ? Tailwind.zinc600 : Tailwind.zinc300 }
    var hover: Color { isDark ? Tailwind.zinc700 : Tailwind.zinc200 }
    var subtleHover: Color { isDark ? Tailwind.zinc700 : Tailwind.zinc100 }
    var plainNoteText: Color { isDark ? Tailwind.zinc300 : Tailwind.zinc700 }

    // Fretboard
    var stringLine: Color { isDark ? Tailwind.zinc600 : Color(hex: 0xE1E1E1) }
    var fretDivider: Color { isDark ? Tailwind.zinc700 : Color(hex: 0xF2F2F2) }
    var fretFooterDivider: Color { isDark ? Tailwind.zinc600 : Color(hex: 0xF2F2F2) }
    var fretFooterBackground: Color { isDark ? Tailwind.zinc700 : Color(hex: 0xF6F6F6) }
    var fretNumber: Color { isDark ? Tailwind.zinc400 : Tailwind.zinc500 }
    var fretMarker: Color { isDark ? Tailwind.zinc500 : Tailwind.zinc400 }

    // Piano
    var whiteKey: Color { isDark ? Tailwind.zinc800 : .white }
    var whiteKeyHover: Color { isDark ? Tailwind.zinc700 : Tailwind.zinc100 }
    var whiteKeyBorder: Color { isDark ? Tailwind.zinc600 : Color(hex: 0xEDE9E9) }
    var blackKey: Color { isDark ? Tailwind.zinc700 : Tailwind.zinc200 }
    var blackKeyHover: Color { isDark ? Tailwind.zinc600 : Tailwind.zinc300 }
    var pianoPlainText: Color { isDark ? Tailwind.zinc300 : Tailwind.zinc600 }
    var blackKeyPlainText: Color { isDark ? Tailwind.zinc400 : Tailwind.zinc600 }

    // Chips and controls
    var chip: Color { isDark ? Tailwind.zinc700 : Tailwind.zinc100 }
    var chipHover: Color { isDark ? Tailwind.zinc600 : Tailwind.zinc200 }
    var chipActive: Color { isDark ? Tailwind.zinc600 : Tailwind.zinc200 }
    var chipActiveRing: Color { isDark ? Tailwind.zinc500 : Tailwind.zinc400 }
    var overflowChip: Color { isDark ? Tailwind.zinc700 : Tailwind.zinc200 }
    var overflowChipText: Color { isDark ? Tailwind.zinc300 : Tailwind.zinc600 }

    // Warning banner
    var warningBackground: Color { isDark ? Color(hex: 0x78350F, opacity: 0.5) : Color(hex: 0xFFFBEB) }
    var warningBorder: Color { isDark ? Color(hex: 0xB45309) : Color(hex: 0xFDE68A) }
    var warningText: Color { isDark ? Color(hex: 0xFDE68A) : Color(hex: 0x92400E) }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme(isDark: false)
}

private struct LayoutWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1000
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }

    /// Width of the main window content, for the web app's responsive breakpoints.
    var layoutWidth: CGFloat {
        get { self[LayoutWidthKey.self] }
        set { self[LayoutWidthKey.self] = newValue }
    }
}

/// A rounded card matching the web app's panels.
struct Card<Content: View>: View {
    @Environment(\.theme) private var theme
    var padding: EdgeInsets
    @ViewBuilder var content: Content

    init(padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16), @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(theme.cardBorder, lineWidth: 1))
    }
}

/// Button style that shows a background on hover (pointer) or press (touch).
struct HighlightButtonStyle: ButtonStyle {
    var normal: Color = .clear
    var highlighted: Color
    var cornerRadius: CGFloat = 0

    func makeBody(configuration: Configuration) -> some View {
        HighlightBody(configuration: configuration, normal: normal, highlighted: highlighted, cornerRadius: cornerRadius)
    }

    private struct HighlightBody: View {
        let configuration: Configuration
        let normal: Color
        let highlighted: Color
        let cornerRadius: CGFloat
        @State private var isHovered = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .background(
                    (isEnabled && (isHovered || configuration.isPressed)) ? highlighted : normal,
                    in: RoundedRectangle(cornerRadius: cornerRadius)
                )
                .contentShape(Rectangle())
                #if os(macOS)
                .onHover { isHovered = $0 }
                #else
                // Touch screens have no hover; iPad pointers get the system highlight instead.
                .hoverEffect(.highlight)
                #endif
        }
    }
}
