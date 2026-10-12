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
    static let darkMode = "moon.fill"
    static let lightMode = "sun.max.fill"
}

/// Which instrument fills the screen on an iPhone held sideways.
enum LandscapeInstrument: String {
    case guitar
    case piano
}

/// Top bar: key picker on the left, playback and app controls on the right.
/// Selection controls live in the chord panel.
struct HeaderView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.layoutWidth) private var layoutWidth
    /// Shown on iPhone in landscape, where one instrument fills the screen.
    var instrumentChoice: Binding<LandscapeInstrument>?

    var body: some View {
        let state = model.state
        let size: CGFloat = layoutWidth >= 600 ? 32 : 40
        HStack(spacing: 12) {
            KeyPickerMenu(selection: Binding(
                get: { model.state.selectedKey },
                set: { model.state.selectedKey = $0 }
            ))
            Spacer(minLength: 0)
            if let instrumentChoice {
                Picker("Instrument", selection: instrumentChoice) {
                    Label("Guitar", systemImage: "guitars").tag(LandscapeInstrument.guitar)
                    Label("Piano", systemImage: "pianokeys").tag(LandscapeInstrument.piano)
                }
                .pickerStyle(.segmented)
                .fixedSize()
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
                IconButton(
                    symbol: state.darkMode ? ActionIcon.lightMode : ActionIcon.darkMode,
                    help: state.darkMode ? "Switch to light mode" : "Switch to dark mode",
                    size: size
                ) {
                    model.toggleDarkMode()
                }
                IconButton(symbol: ActionIcon.settings, help: "Settings", size: size) {
                    model.isSettingsPresented = true
                }
            }
        }
    }
}

struct IconButton: View {
    @Environment(\.theme) private var theme
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
                .frame(width: size, height: size)
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

/// A key menu (No key, 12 major, 12 minor) showing the chosen key and, on wider screens, its notes.
struct KeyPickerMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.layoutWidth) private var layoutWidth
    @Binding var selection: MusicalKey?
    var showsScale = true
    @State private var isHovered = false

    var body: some View {
        let sharpsOnly = model.state.sharpsOnly
        Menu {
            keyToggle(nil, title: "No key")
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
                Text(selection?.name(sharpsOnly: sharpsOnly) ?? "No key")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                if showsScale, let key = selection, layoutWidth >= 600 {
                    Text(key.noteNames(sharpsOnly: sharpsOnly).joined(separator: " "))
                        .font(.system(size: 12))
                        .foregroundStyle(Tailwind.zinc500)
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
        .fixedSize()
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
