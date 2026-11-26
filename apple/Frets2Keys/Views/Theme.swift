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

extension Color {
    /// This color with its saturation and brightness scaled, keeping its hue.
    func adjusted(saturation: Double, brightness: Double) -> Color {
        let c = resolve(in: EnvironmentValues())
        let r = Double(c.red), g = Double(c.green), b = Double(c.blue)
        let maxC = max(r, g, b), minC = min(r, g, b), delta = maxC - minC
        var hue = 0.0
        if delta > 0 {
            if maxC == r { hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
            else if maxC == g { hue = (b - r) / delta + 2 }
            else { hue = (r - g) / delta + 4 }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        let sat = maxC == 0 ? 0 : delta / maxC
        return Color(
            hue: hue,
            saturation: min(1, sat * saturation),
            brightness: min(1, maxC * brightness),
            opacity: Double(c.opacity)
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
    /// Text on the dark-mode tint: a light shade (Tailwind 300) of the same hue.
    let darkText: Color

    func tint(dark: Bool) -> Color { dark ? dark900.opacity(0.3) : light100 }
    func border(dark: Bool) -> Color { dark ? darkBorder : lightBorder }

    static let all: [ScaleDegreePalette] = [
        // red, orange, yellow, green, cyan, blue, purple
        .init(light100: Color(hex: 0xFEE2E2), solid: Color(hex: 0xEF4444), lightBorder: Color(hex: 0xF87171), dark900: Color(hex: 0x7F1D1D), darkBorder: Color(hex: 0xB91C1C), darkText: Color(hex: 0xFCA5A5)),
        .init(light100: Color(hex: 0xFFEDD5), solid: Color(hex: 0xEA580C), lightBorder: Color(hex: 0xFB923C), dark900: Color(hex: 0x7C2D12), darkBorder: Color(hex: 0xC2410C), darkText: Color(hex: 0xFDBA74)),
        .init(light100: Color(hex: 0xFEF9C3), solid: Color(hex: 0xCA8A04), lightBorder: Color(hex: 0xFACC15), dark900: Color(hex: 0x713F12), darkBorder: Color(hex: 0xA16207), darkText: Color(hex: 0xFDE047)),
        .init(light100: Color(hex: 0xDCFCE7), solid: Color(hex: 0x16A34A), lightBorder: Color(hex: 0x4ADE80), dark900: Color(hex: 0x14532D), darkBorder: Color(hex: 0x15803D), darkText: Color(hex: 0x86EFAC)),
        .init(light100: Color(hex: 0xCFFAFE), solid: Color(hex: 0x0891B2), lightBorder: Color(hex: 0x22D3EE), dark900: Color(hex: 0x164E63), darkBorder: Color(hex: 0x0E7490), darkText: Color(hex: 0x67E8F9)),
        .init(light100: Color(hex: 0xDBEAFE), solid: Color(hex: 0x3B82F6), lightBorder: Color(hex: 0x60A5FA), dark900: Color(hex: 0x1E3A8A), darkBorder: Color(hex: 0x1D4ED8), darkText: Color(hex: 0x93C5FD)),
        .init(light100: Color(hex: 0xF3E8FF), solid: Color(hex: 0xA855F7), lightBorder: Color(hex: 0xC084FC), dark900: Color(hex: 0x581C87), darkBorder: Color(hex: 0x7E22CE), darkText: Color(hex: 0xD8B4FE)),
    ]
}

enum NotePalette {
    // pink, lime, teal, indigo, rose, then fuchsia and stone for scales with fewer than 7 notes.
    static let outOfKey: [Color] = [
        Color(hex: 0xEC4899), Color(hex: 0x65A30D), Color(hex: 0x0D9488), Color(hex: 0x6366F1), Color(hex: 0xF43F5E),
        Color(hex: 0xC026D3), Color(hex: 0x78716C),
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
        case .outOfKey(let index): return outOfKey[index % outOfKey.count]
        case .chromatic(let pitchClass): return chromatic[pitchClass]
        }
    }

    /// A faint wash of a role's color: the scale-degree tint for in-key notes, else a light
    /// version of the solid color.
    static func tint(for role: NoteColorRole, dark: Bool) -> Color {
        if case .scaleDegree(let degree) = role { return ScaleDegreePalette.all[degree].tint(dark: dark) }
        return solid(for: role).opacity(dark ? 0.16 : 0.12)
    }
}

/// Surface and text colors (the app is dark only).
struct Theme {
    /// Always true: the app only has a dark appearance. Kept so views can still ask.
    let isDark: Bool

    /// Dark mode's one line color: a faint lift of whatever it sits on, so the lines that
    /// separate cards, sections, frets and keys stay equally faint on the page and in the cards.
    private static let darkHairline = Color.white.opacity(0.045)

    /// A note's solid color, for selected notes. Dark mode mutes it: less saturated and a
    /// little darker, so it doesn't glare off the dark surfaces.
    func noteSolid(_ role: NoteColorRole) -> Color {
        let solid = NotePalette.solid(for: role)
        return solid.adjusted(saturation: 0.85, brightness: 0.55)
    }

    /// Text on a selected note: white in light mode. Dark mode uses the same pastel as an
    /// unselected in-key note's text (other notes get a pastel worked out the same way).
    func noteSolidText(_ role: NoteColorRole) -> Color {
        if case .scaleDegree(let degree) = role { return ScaleDegreePalette.all[degree].darkText }
        return NotePalette.solid(for: role).adjusted(saturation: 0.55, brightness: 1.05)
    }

    /// Behind the top bar and the chord panel, a shade darker than the instruments' surface.
    var pageBackground: Color { Tailwind.zinc900 }
    /// Behind the guitars and piano, a step lighter than the page so the cards stand off it.
    var instrumentBackground: Color { Color(hex: 0x222225) }
    var cardBackground: Color { Tailwind.zinc800 }
    var cardBorder: Color { Self.darkHairline }
    /// The hairlines between the page's full-width sections.
    var sectionDivider: Color { Self.darkHairline }
    var primaryText: Color { Tailwind.zinc100 }
    var secondaryText: Color { Tailwind.zinc200 }
    var mutedText: Color { Tailwind.zinc500 }
    var icon: Color { Tailwind.zinc400 }
    var iconDisabled: Color { Tailwind.zinc600 }
    var hover: Color { Tailwind.zinc700 }
    var subtleHover: Color { Tailwind.zinc700 }
    var plainNoteText: Color { Tailwind.zinc300 }

    // Fretboard
    var stringLine: Color { Color(hex: 0x333338) }
    /// Dark mode draws the fretboard as a grid of cells, like the piano's keys: no string lines,
    /// solid page-colored gaps between cells, and selected notes filling their whole cell.
    var fretboardGrid: Bool { true }
    var fretDivider: Color { pageBackground }
    var fretFooterDivider: Color { pageBackground }
    /// The same as the rest of the fretboard, so the fret numbers read as part of the card.
    var fretFooterBackground: Color { instrumentBackground }
    /// The hairline between the strings and the fret numbers.
    var fretFooterRule: Color { pageBackground }
    /// The nut (or the capo, when one is on): a lighter line than the fret gaps.
    var nutLine: Color { Tailwind.zinc600 }
    var fretNumber: Color { Tailwind.zinc400 }
    var fretMarker: Color { Tailwind.zinc500 }

    // Piano
    /// The piano's surface, so in dark mode the white keys are the page color.
    var whiteKey: Color { instrumentBackground }
    var whiteKeyHover: Color { Color(hex: 0x2E2E32) }
    /// Dark mode draws the gaps between keys in the page color, solid, so neighboring selected
    /// keys stay apart instead of blurring together.
    var whiteKeyBorder: Color { pageBackground }
    /// Black keys are only a shade off the white keys, so the colored notes stand out.
    var blackKey: Color { Color(hex: 0x2B2B2F) }
    var blackKeyHover: Color { Tailwind.zinc700 }
    var pianoPlainText: Color { Tailwind.zinc300 }
    var blackKeyPlainText: Color { Tailwind.zinc400 }

    // Chips and controls
    /// Buttons sitting on a card (the selected chord's actions).
    var cardButton: Color { Color.white.opacity(0.06) }
    var cardButtonHover: Color { Color.white.opacity(0.11) }
    /// The main action button (the chord bank's Add): blue, muted in dark mode like the notes.
    var primaryButton: Color { Tailwind.blue500.adjusted(saturation: 0.85, brightness: 0.7) }
    var primaryButtonHover: Color { Tailwind.blue500.adjusted(saturation: 0.85, brightness: 0.8) }
    var chip: Color { Tailwind.zinc700 }
    /// Chips sitting directly on the page background (the bottom panel): white in light mode,
    /// outlined so they stand out from the page.
    var pageChip: Color { Tailwind.zinc700 }
    var pageChipBorder: Color { .clear }
    var chipHover: Color { Tailwind.zinc600 }
    var chipActive: Color { Tailwind.zinc600 }
    var chipActiveRing: Color { Tailwind.zinc500 }
    var overflowChip: Color { Tailwind.zinc700 }
    var overflowChipText: Color { Tailwind.zinc300 }

    // Warning banner
    var warningBackground: Color { Color(hex: 0x78350F, opacity: 0.5) }
    var warningBorder: Color { Color(hex: 0xB45309) }
    var warningText: Color { Color(hex: 0xFDE68A) }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme(isDark: true)
}

private struct LayoutWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1000
}

private struct CompactLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

private struct InstrumentFillHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }

    /// A narrow window (or iPhone): short key names, Add as a menu, sections' chords under their
    /// names, and the song and chord bank stacked.
    var isCompactLayout: Bool {
        get { self[CompactLayoutKey.self] }
        set { self[CompactLayoutKey.self] = newValue }
    }

    /// When set, instruments stretch to fill this height (iPhone landscape).
    var instrumentFillHeight: CGFloat? {
        get { self[InstrumentFillHeightKey.self] }
        set { self[InstrumentFillHeightKey.self] = newValue }
    }

    /// Width of the main window content, for the web app's responsive breakpoints.
    var layoutWidth: CGFloat {
        get { self[LayoutWidthKey.self] }
        set { self[LayoutWidthKey.self] = newValue }
    }
}

/// Corner radius shared by the instrument cards and the chord-limit banner.
let cardCornerRadius: CGFloat = 16

/// A rounded card holding an instrument, which runs right to its edges and is clipped to its corners.
struct InstrumentCard<Content: View>: View {
    @Environment(\.theme) private var theme
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.instrumentBackground)
            .clipShape(shape)
            .overlay(shape.strokeBorder(theme.cardBorder, lineWidth: 1))
    }
}

/// A full-width hairline, between the instruments and the chord panel and within the panel.
struct SectionDivider: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Rectangle()
            .fill(theme.sectionDivider)
            .frame(height: 1)
    }
}

/// A rounded rectangle drawn inside its frame, by `dx` at the sides and `dy` at the top and bottom.
struct InsetRoundedRectangle: Shape {
    var cornerRadius: CGFloat
    var dx: CGFloat = 0
    var dy: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: cornerRadius).path(in: rect.insetBy(dx: dx, dy: dy))
    }
}

/// The icon buttons' hover fill (`theme.hover`, like the top bar's buttons) for things that aren't
/// `Button`s, such as a `Menu`'s label.
struct IconHoverFill: ViewModifier {
    @Environment(\.theme) private var theme
    var cornerRadius: CGFloat = 8
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(isHovered ? theme.hover : .clear, in: RoundedRectangle(cornerRadius: cornerRadius))
            #if os(macOS)
            .onHover { isHovered = $0 }
            #else
            .hoverEffect(.highlight)
            #endif
    }
}

extension View {
    func iconHoverFill(cornerRadius: CGFloat = 8) -> some View {
        modifier(IconHoverFill(cornerRadius: cornerRadius))
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

enum Device {
    /// iPhone (in any orientation), as opposed to iPad or Mac.
    static var isPhone: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .phone
        #else
        return false
        #endif
    }
}

extension View {
    /// Limits content to the app's maximum width and centers it.
    func centered(maxWidth: CGFloat = 1280) -> some View {
        frame(maxWidth: maxWidth).frame(maxWidth: .infinity)
    }
}
