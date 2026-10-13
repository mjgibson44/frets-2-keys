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
    static let loop = "repeat"
    static let settings = "gearshape.fill"
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

/// Top bar: key picker on the left, playback and settings on the right.
/// Selection controls live in the chord panel.
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
            ), showsLabelOptions: true)
            if layoutWidth >= 700 {
                NoteLabelPicker()
            }
            if let instrumentChoice, instrumentOptions.count > 1 {
                // Takes the space between the key menu and the buttons.
                InstrumentTabs(selection: instrumentChoice, options: instrumentOptions)
                    .frame(maxWidth: .infinity)
            } else {
                Spacer(minLength: 0)
            }
            HStack(spacing: 0) {
                IconButton(symbol: ActionIcon.play, help: "Play all selected notes (Enter)", size: size, isEnabled: state.hasSelection) {
                    model.play()
                }
                IconButton(
                    symbol: ActionIcon.loop,
                    help: model.isLooping ? "Stop loop (Space)" : "Loop playback (Space)",
                    size: size,
                    isEnabled: state.canLoop || model.isLooping,
                    isActive: model.isLooping
                ) {
                    model.toggleLoop()
                }
                IconButton(symbol: ActionIcon.settings, help: "Settings", size: size) {
                    model.isSettingsPresented = true
                }
            }
        }
    }
}

/// Tabs for the instruments that are turned on, with full names when they fit ("Guitar 1"), or
/// short ones ("G1", "G2", "PN") when space is tight.
private struct InstrumentTabs: View {
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isActive ? .white : (isEnabled ? theme.icon : theme.iconDisabled))
                .frame(width: fillsWidth ? nil : size, height: size)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
        }
        .buttonStyle(HighlightButtonStyle(
            normal: isActive ? Tailwind.green500 : .clear,
            highlighted: isActive ? Color(hex: 0x16A34A) : theme.hover,
            cornerRadius: 8
        ))
        .disabled(!isEnabled)
        .help(help)
        .accessibilityLabel(help)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

/// Notes / Degrees / Intervals, for the top bar on wide screens. (Narrower screens have it in the
/// key menu.)
struct NoteLabelPicker: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Picker("Label Notes With", selection: Binding(
            get: { model.state.noteLabelContent },
            set: { model.state.noteLabelContent = $0 }
        )) {
            ForEach(NoteLabelContent.allCases) { content in
                Text(content.title).tag(content)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .help("Label notes with their names, scale degrees, or intervals from the chord's root (N)")
    }
}

/// A key menu (No key, 12 major, 12 minor, other scales) showing the chosen key and, on wider
/// screens, its notes or degrees.
struct KeyPickerMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.layoutWidth) private var layoutWidth
    @Binding var selection: MusicalKey?
    var showsScale = true
    /// Adds the Notes / Degrees / Intervals choice (the app's own key menu).
    var showsLabelOptions = false
    @State private var isHovered = false

    var body: some View {
        let sharpsOnly = model.state.sharpsOnly
        Menu {
            // Wide screens have this in the top bar instead.
            if showsLabelOptions && layoutWidth < 700 {
                Section("Label Notes With") {
                    Picker("Label Notes With", selection: Binding(
                        get: { model.state.noteLabelContent },
                        set: { model.state.noteLabelContent = $0 }
                    )) {
                        ForEach(NoteLabelContent.allCases) { content in
                            Text(content.title).tag(content)
                        }
                    }
                    .pickerStyle(.palette)
                }
            }
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
                // Narrow screens use short names ("A min. pent.") so the top bar fits.
                Text(selection.map { layoutWidth >= 600 ? $0.name(sharpsOnly: sharpsOnly) : $0.shortName(sharpsOnly: sharpsOnly) } ?? "No key")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                if showsScale, let key = selection, layoutWidth >= 600 {
                    let showsDegrees = showsLabelOptions && model.state.noteLabelContent == .degrees
                    Text((showsDegrees ? key.degreeLabels : key.noteNames(sharpsOnly: sharpsOnly)).joined(separator: " "))
                        .font(.system(size: 12))
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

    /// A menu item with a checkmark when it's the current key.
    private func keyToggle(_ key: MusicalKey?, title: String) -> some View {
        Toggle(title, isOn: Binding(
            get: { selection == key },
            set: { if $0 { selection = key } }
        ))
    }
}
