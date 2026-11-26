import SwiftUI
import Frets2KeysCore

/// SF Symbols matching the web app's icons, shared by the toolbar and the tutorial.
enum ActionIcon {
    static let clear = "xmark"
    static let update = "checkmark"
    static let saveNew = "plus"
    static let transposeUp = "arrow.up"
    static let transposeDown = "arrow.down"
    static let play = "play.fill"
    static let stop = "stop.fill"
    static let loop = "repeat"
    static let settings = "gearshape.fill"
    static let sidebar = "sidebar.right"
    static let songPanel = "rectangle.bottomthird.inset.filled"
}

/// Which instrument an iPhone shows (it shows one at a time).
enum InstrumentChoice: String, CaseIterable, Identifiable {
    // "guitar" is Guitar 1; the raw value predates the second guitar option.
    case guitar
    case guitar2
    case piano

    var id: String { rawValue }

    var title: String {
        switch self {
        case .guitar: return "Guitar 1"
        case .guitar2: return "Guitar 2"
        case .piano: return "Piano"
        }
    }

    /// For tabs when space is tight.
    var shortTitle: String {
        switch self {
        case .guitar: return "G1"
        case .guitar2: return "G2"
        case .piano: return "PN"
        }
    }

    /// The choices available for the current instruments.
    static func available(guitars: Int, piano: Bool) -> [InstrumentChoice] {
        let guitarChoices: [InstrumentChoice] = Array([.guitar, .guitar2].prefix(guitars))
        return guitarChoices + (piano ? [.piano] : [])
    }
}

/// Top bar (iPhone): key picker on the left, play and settings on the right. iPad and Mac have no
/// top bar: the selected chord and `WindowButtonsCard` sit above the instruments instead.
struct HeaderView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.layoutWidth) private var layoutWidth
    /// Shown on iPhone, where one instrument is shown at a time.
    var instrumentChoice: Binding<InstrumentChoice>?
    var instrumentOptions: [InstrumentChoice] = []

    var body: some View {
        let state = model.state
        let size: CGFloat = layoutWidth >= 600 ? 32 : 40
        HStack(spacing: 12) {
            KeyPickerMenu(selection: Binding(
                get: { model.state.selectedKey },
                set: { model.state.selectedKey = $0 }
            ))
            if let instrumentChoice, instrumentOptions.count > 1 {
                // Takes the space between the key menu and the buttons.
                InstrumentTabs(selection: instrumentChoice, options: instrumentOptions)
                    .frame(maxWidth: .infinity)
            } else {
                Spacer(minLength: 0)
            }
            HStack(spacing: 0) {
                // One play button: plays on a loop until pressed again.
                IconButton(
                    symbol: model.isLoopingSelection ? ActionIcon.stop : ActionIcon.play,
                    help: model.isLoopingSelection ? "Stop (Space)" : "Play this chord on repeat (Space)",
                    size: size,
                    isEnabled: state.hasSelection || model.isLoopingSelection,
                    isActive: model.isLoopingSelection
                ) {
                    model.toggleSelectionLoop()
                }
                IconButton(symbol: ActionIcon.settings, help: "Settings", size: size) {
                    model.isSettingsPresented = true
                }
            }
        }
    }
}

/// iPad and Mac: the song panel, chord bank and settings buttons, at the right end of the top bar.
struct WindowButtons: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.isCompactLayout) private var isCompact

    var body: some View {
        if isCompact {
            phoneMenu
        } else {
            buttons
        }
    }

    #if os(iOS)
    @State private var isMenuShowing = false

    /// Narrow windows and iPhone: the panels, instruments and settings folded into one popover of
    /// switches, to save room in the top bar.
    private var phoneMenu: some View {
        Button {
            isMenuShowing = true
        } label: {
            menuIcon
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
        .accessibilityLabel("View and settings")
        .popover(isPresented: $isMenuShowing, arrowEdge: .top) {
            ViewMenuPopover(isShowing: $isMenuShowing)
                .environment(\.theme, theme)
                .presentationCompactAdaptation(.popover)
                .presentationBackground(theme.pageBackground)
                .preferredColorScheme(.dark)
        }
    }
    #else
    /// Narrow windows: the three folded into one menu to save room in the top bar.
    private var phoneMenu: some View {
        Menu {
            Toggle(isOn: Binding(
                get: { model.isSongPanelPresented },
                set: { on in withAnimation { model.isSongPanelPresented = on } }
            )) {
                Label("Song Structure", systemImage: ActionIcon.songPanel)
            }
            Toggle(isOn: Binding(
                get: { model.isChordBankPresented },
                set: { on in withAnimation { if on { model.openChordBank() } else { model.isChordBankPresented = false } } }
            )) {
                Label("Chord Bank", systemImage: ActionIcon.sidebar)
            }
            Divider()
            // Which instruments show.
            Toggle("Guitar 1", isOn: Binding(
                get: { model.showsGuitar },
                set: { on in withAnimation { model.setShowsGuitar(on) } }
            ))
            Toggle("Guitar 2", isOn: Binding(
                get: { model.showsSecondGuitar },
                set: { on in withAnimation { model.setShowsSecondGuitar(on) } }
            ))
            Toggle("Piano", isOn: Binding(
                get: { model.state.showPiano },
                set: { on in withAnimation { model.setShowsPiano(on) } }
            ))
            Divider()
            Button("Settings…", systemImage: ActionIcon.settings) {
                model.isSettingsPresented = true
            }
        } label: {
            menuIcon
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        // Level with the first line's buttons, which sit centered in a slightly taller row.
        .padding(.top, 2)
        .accessibilityLabel("View and settings")
    }
    #endif

    /// Sized like the top bar's other icon buttons.
    private var menuIcon: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(theme.icon)
            .frame(width: 30, height: 30)
            .contentShape(Rectangle())
            .iconHoverFill()
    }

    private var buttons: some View {
        HStack(spacing: 2) {
                IconButton(
                    symbol: ActionIcon.songPanel,
                    help: model.isSongPanelPresented ? "Hide song (⌘J)" : "Show song (⌘J)",
                    size: 32,
                    isOn: model.isSongPanelPresented
                ) {
                    withAnimation { model.isSongPanelPresented.toggle() }
                }
                IconButton(
                    symbol: ActionIcon.sidebar,
                    help: model.isChordBankPresented ? "Hide chord bank (⌘B)" : "Show chord bank (⌘B)",
                    size: 32,
                    isOn: model.isChordBankPresented
                ) {
                    withAnimation {
                        if model.isChordBankPresented {
                            model.isChordBankPresented = false
                        } else {
                            model.openChordBank()
                        }
                    }
                }
                IconButton(symbol: ActionIcon.settings, help: "Settings", size: 32) {
                    model.isSettingsPresented = true
                }
        }
    }
}

#if os(iOS)
/// iPhone's view menu: switches for the song structure, the chord bank and the instruments, then
/// Settings. iPhone shows two instruments at most, so a second guitar is turned on in Settings.
private struct ViewMenuPopover: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Binding var isShowing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row("Song Structure", symbol: ActionIcon.songPanel, isOn: Binding(
                get: { model.isSongPanelPresented },
                set: { on in withAnimation { model.isSongPanelPresented = on } }
            ))
            row("Chord Bank", symbol: ActionIcon.sidebar, isOn: Binding(
                get: { model.isChordBankPresented },
                set: { on in withAnimation { if on { model.openChordBank() } else { model.isChordBankPresented = false } } }
            ))
            Divider().padding(.vertical, 6)
            row("Guitar", symbol: "guitars", isOn: Binding(
                get: { model.showsGuitar },
                set: { on in withAnimation { model.setShowsGuitar(on) } }
            ))
            .disabled(model.showsGuitar && !model.canHideGuitar)
            if !AppModel.limitsInstruments {
                row("Guitar 2", symbol: "guitars", isOn: Binding(
                    get: { model.showsSecondGuitar },
                    set: { on in withAnimation { model.setShowsSecondGuitar(on) } }
                ))
            }
            row("Piano", symbol: "pianokeys", isOn: Binding(
                get: { model.state.showPiano },
                set: { on in withAnimation { model.setShowsPiano(on) } }
            ))
            .disabled(model.state.showPiano && !model.canHidePiano)
            Divider().padding(.vertical, 6)
            Button {
                isShowing = false
                model.isSettingsPresented = true
            } label: {
                Label("Settings…", systemImage: ActionIcon.settings)
                    .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 15))
        .foregroundStyle(theme.primaryText)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(width: 260)
    }

    private func row(_ title: String, symbol: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: symbol)
        }
        .tint(Tailwind.green500)
        .frame(minHeight: 40)
    }
}
#endif

/// Tabs for the instruments that are turned on, with full names when they fit ("Guitar 1"), or
/// short ones ("G1", "G2", "PN") when space is tight.
struct InstrumentTabs: View {
    @Binding var selection: InstrumentChoice
    let options: [InstrumentChoice]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            tabs { option in
                // A lone guitar doesn't need a number.
                option == .guitar && !options.contains(.guitar2) ? "Guitar" : option.title
            }
            tabs(\.shortTitle)
        }
        .accessibilityLabel("Instrument")
    }

    private func tabs(_ title: @escaping (InstrumentChoice) -> String) -> some View {
        Picker("Instrument", selection: $selection) {
            ForEach(options) { option in
                Text(title(option))
                    .accessibilityLabel(option.title)
                    .tag(option)
            }
        }
        .pickerStyle(.segmented)
        .fixedSize()
    }
}

private struct IconButtonFillsWidthKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Icon buttons in a row share its width equally (a wider tap target) instead of staying square.
    var iconButtonFillsWidth: Bool {
        get { self[IconButtonFillsWidthKey.self] }
        set { self[IconButtonFillsWidthKey.self] = newValue }
    }
}

struct IconButton: View {
    @Environment(\.theme) private var theme
    @Environment(\.iconButtonFillsWidth) private var fillsWidth
    let symbol: String
    let help: String
    var size: CGFloat = 32
    var isEnabled = true
    var isActive = false
    /// A toggle that's on (an open sidebar): a steady hover-colored fill and a brighter icon.
    var isOn = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isActive ? .white : (isOn ? theme.primaryText : (isEnabled ? theme.icon : theme.iconDisabled)))
                .frame(width: fillsWidth ? nil : size, height: size)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
        }
        .buttonStyle(HighlightButtonStyle(
            normal: isActive ? Tailwind.green500 : (isOn ? theme.hover : .clear),
            highlighted: isActive ? Color(hex: 0x16A34A) : (isOn ? theme.chipHover : theme.hover),
            cornerRadius: 8
        ))
        .disabled(!isEnabled)
        .help(help)
        .accessibilityLabel(help)
        .accessibilityAddTraits(isActive || isOn ? .isSelected : [])
    }
}

/// A key menu (No key, 12 major, 12 minor, other scales) showing the chosen key and, on wider
/// screens, its notes or degrees.
struct KeyPickerMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.layoutWidth) private var layoutWidth
    @Environment(\.isCompactLayout) private var isCompact
    @Binding var selection: MusicalKey?
    var showsScale = true
    /// A treble clef before the name (the instruments' key, in the selected chord's card).
    var showsClef = false
    @State private var isHovered = false

    var body: some View {
        let sharpsOnly = model.state.sharpsOnly
        Menu {
            keyToggle(nil, title: "No key")
            Menu("More Scales") {
                ForEach(ScaleType.Family.allCases, id: \.self) { family in
                    Section(family.rawValue) {
                        ForEach(family.types.filter { $0 != .major && $0 != .minor }) { type in
                            Menu(type.name.prefix(1).uppercased() + type.name.dropFirst()) {
                                ForEach(0..<12, id: \.self) { root in
                                    let key = MusicalKey(root: root, type: type)
                                    keyToggle(key, title: key.name(sharpsOnly: sharpsOnly))
                                }
                            }
                        }
                    }
                }
            }
            Section("Major") {
                ForEach(MusicalKey.all.filter { $0.type == .major }) { key in
                    keyToggle(key, title: key.name(sharpsOnly: sharpsOnly))
                }
            }
            Section("Minor") {
                ForEach(MusicalKey.all.filter { $0.type == .minor }) { key in
                    keyToggle(key, title: key.name(sharpsOnly: sharpsOnly))
                }
            }
        } label: {
            HStack(spacing: 8) {
                if showsClef {
                    Text(verbatim: "𝄞")
                        .font(.system(size: 20))
                        .foregroundStyle(theme.icon)
                        .accessibilityHidden(true)
                }
                // Narrow screens use short names ("A min. pent.") so the top bar fits.
                noteText(selection.map { label(for: $0, sharpsOnly: sharpsOnly) } ?? "No key", size: 14, weight: .medium)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                if showsScale, let key = selection, layoutWidth >= 600 {
                    let showsDegrees = model.state.noteLabelContent == .degrees
                    noteText((showsDegrees ? key.degreeLabels : key.noteNames(sharpsOnly: sharpsOnly)).joined(separator: " "), size: 12)
                        .foregroundStyle(Tailwind.zinc500)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Tailwind.zinc500)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isHovered ? theme.hover : .clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        // On narrow screens the name can truncate rather than push the top bar off screen.
        .fixedSize(horizontal: layoutWidth >= 600, vertical: true)
        .layoutPriority(1)
        #if os(macOS)
        .onHover { isHovered = $0 }
        #else
        .hoverEffect(.highlight)
        #endif
        .accessibilityLabel("Key: \(selection?.name(sharpsOnly: sharpsOnly) ?? "No key")")
    }

    /// The key's name in the menu's label: in full ("F major"); compact, as a chord symbol ("F",
    /// "Fm") for major and minor keys, else the short name ("A min. pent.").
    private func label(for key: MusicalKey, sharpsOnly: Bool) -> String {
        guard isCompact || layoutWidth < 600 else { return key.name(sharpsOnly: sharpsOnly) }
        let root = displayName(for: Note(midi: 60 + key.root), key: key, sharpsOnly: sharpsOnly)
        switch key.type {
        case .major: return root
        case .minor: return root + "m"
        default: return key.shortName(sharpsOnly: sharpsOnly)
        }
    }

    /// A menu item with a checkmark when it's the current key.
    private func keyToggle(_ key: MusicalKey?, title: String) -> some View {
        Toggle(title, isOn: Binding(
            get: { selection == key },
            set: { if $0 { selection = key } }
        ))
    }
}
