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

struct HeaderView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.layoutWidth) private var layoutWidth

    var body: some View {
        if layoutWidth >= 880 {
            HStack(spacing: 12) {
                KeyPickerMenu()
                Spacer(minLength: 0)
                selectionSummary
                    .padding(.trailing, 8)
                actionButtons(size: 32)
            }
        } else {
            VStack(spacing: 8) {
                HStack {
                    Spacer(minLength: 0)
                    actionButtons(size: layoutWidth >= 600 ? 32 : 40)
                }
                HStack(spacing: 12) {
                    KeyPickerMenu()
                    Spacer(minLength: 0)
                    selectionSummary
                }
            }
        }
    }

    // MARK: - Chord name and note chips

    @ViewBuilder
    private var selectionSummary: some View {
        let state = model.state
        if state.hasSelection {
            let limit = layoutWidth >= 600 ? 6 : 4
            HStack(spacing: 8) {
                if let chordName = state.chordName {
                    Text(chordName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityLabel("Chord: \(chordName)")
                }
                HStack(spacing: 4) {
                    ForEach(state.selectedNotes.prefix(limit), id: \.self) { note in
                        // The web app shows sharp names here regardless of key.
                        Text(note.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                NotePalette.solid(for: NoteAppearance.colorRole(for: note, key: state.selectedKey)),
                                in: RoundedRectangle(cornerRadius: 4)
                            )
                    }
                    if state.selectedNotes.count > limit {
                        Text("+\(state.selectedNotes.count - limit)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(theme.overflowChipText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(theme.overflowChip, in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Selected notes: " + state.selectedNotes.map(\.description).joined(separator: ", "))
            }
        }
    }

    // MARK: - Toolbar buttons

    private func actionButtons(size: CGFloat) -> some View {
        let state = model.state
        return HStack(spacing: 0) {
            IconButton(symbol: ActionIcon.clear, help: "Clear all notes (Delete)", size: size, isEnabled: state.hasSelection) {
                model.clearSelection()
            }
            IconButton(symbol: ActionIcon.update, help: "Update existing chord (S)", size: size, isEnabled: state.canUpdateActiveChord) {
                model.updateActiveChord()
            }
            IconButton(symbol: ActionIcon.saveNew, help: "Save as new chord (A)", size: size, isEnabled: state.canSaveAsNew) {
                model.saveAsNewChord()
            }
            IconButton(symbol: ActionIcon.transposeUp, help: "Transpose up 1 semitone (+)", size: size, isEnabled: state.hasSelection) {
                model.transpose(by: 1)
            }
            IconButton(symbol: ActionIcon.transposeDown, help: "Transpose down 1 semitone (-)", size: size, isEnabled: state.hasSelection) {
                model.transpose(by: -1)
            }
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

struct KeyPickerMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.layoutWidth) private var layoutWidth
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
                Text(model.state.selectedKey?.name(sharpsOnly: sharpsOnly) ?? "No key")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                if let key = model.state.selectedKey, layoutWidth >= 600 {
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
        .accessibilityLabel("Key: \(model.state.selectedKey?.name(sharpsOnly: sharpsOnly) ?? "No key")")
    }

    /// A menu item with a checkmark when it's the current key.
    private func keyToggle(_ key: MusicalKey?, title: String) -> some View {
        Toggle(title, isOn: Binding(
            get: { model.state.selectedKey == key },
            set: { if $0 { model.state.selectedKey = key } }
        ))
    }
}
