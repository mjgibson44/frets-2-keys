import SwiftUI
import Frets2KeysCore

@main
struct Frets2KeysApp: App {
    @State private var model = Self.makeModel()

    /// UI tests pass `-UITestFreshState` to start from an empty, unsynced state each run.
    private static func makeModel() -> AppModel {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-UITestFreshState") {
            let suite = "Frets2KeysUITests"
            UserDefaults().removePersistentDomain(forName: suite)
            return AppModel(defaults: UserDefaults(suiteName: suite)!, syncWithICloud: false)
        }
        #endif
        return AppModel()
    }

    var body: some Scene {
        #if os(macOS)
        Window("Frets 2 Keys", id: "main") {
            ContentView()
                .environment(model)
                .frame(minWidth: 480, minHeight: 480)
        }
        .defaultSize(width: 1280, height: 860)
        .commands { AppCommands(model: model) }
        #else
        WindowGroup {
            ContentView()
                .environment(model)
        }
        .commands { AppCommands(model: model) }
        #endif
    }
}

/// Menu bar commands (macOS, and iPadOS with a hardware keyboard), using the web app's shortcuts.
struct AppCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { model.isSettingsPresented = true }
                .keyboardShortcut(",", modifiers: .command)
        }
        CommandGroup(replacing: .help) {
            Button("Frets 2 Keys Tutorial") { model.isTutorialPresented = true }
        }
        CommandMenu("Chord") {
            let state = model.state
            // Plain-key shortcuts are disabled while a sheet is up so typing in settings works.
            let enabled = !model.isSheetPresented
            Button("Play") { model.play() }
                .plainKeyShortcut(.return)
                .disabled(!enabled || !state.hasSelection)
            Button(model.isLooping ? "Stop Loop" : "Loop") { model.toggleLoop() }
                .plainKeyShortcut(.space)
                .disabled(!enabled || !(state.canLoop || model.isLooping))
            Divider()
            Button("Save as New Chord") { model.saveAsNewChord() }
                .plainKeyShortcut("a")
                .disabled(!enabled || !state.canSaveAsNew)
            Button("Update Saved Chord") { model.updateActiveChord() }
                .plainKeyShortcut("s")
                .disabled(!enabled || !state.canUpdateActiveChord)
            Button("Clear Selection") { model.clearSelection() }
                .plainKeyShortcut(.delete)
                .disabled(!enabled || !state.hasSelection)
            Divider()
            Button("Transpose Up") { model.transpose(by: 1) }
                .plainKeyShortcut("=")
                .disabled(!enabled || !state.hasSelection)
            Button("Transpose Down") { model.transpose(by: -1) }
                .plainKeyShortcut("-")
                .disabled(!enabled || !state.hasSelection)
            Divider()
            Button(model.isChordBankPresented ? "Hide Chord Bank" : "Show Chord Bank") {
                if model.isChordBankPresented {
                    model.isChordBankPresented = false
                } else {
                    model.openChordBank()
                }
            }
            .keyboardShortcut("b", modifiers: .command)
            .disabled(!enabled)
            Divider()
            Button("Previous Saved Chord") { model.selectPreviousChord() }
                .plainKeyShortcut(.leftArrow)
                .disabled(!enabled || state.chordsOnly.isEmpty)
            Button("Next Saved Chord") { model.selectNextChord() }
                .plainKeyShortcut(.rightArrow)
                .disabled(!enabled || state.chordsOnly.isEmpty)
            Divider()
            Picker("Label Notes With", selection: Binding(
                get: { model.state.noteLabelContent },
                set: { model.state.noteLabelContent = $0 }
            )) {
                ForEach(NoteLabelContent.allCases) { content in
                    Text(content.title).tag(content)
                }
            }
            Button("Next Note Labels") { model.cycleNoteLabels() }
                .plainKeyShortcut("n")
                .disabled(!enabled)
        }
        CommandMenu("Sets") {
            let state = model.state
            let enabled = !model.isSheetPresented
            ForEach(state.chordSets) { set in
                Toggle(set.name, isOn: Binding(
                    get: { set.id == model.state.activeSetID },
                    set: { if $0 { model.selectSet(set.id) } }
                ))
            }
            Divider()
            SetActions(model: model)
                .disabled(!enabled)
        }
        CommandGroup(after: .toolbar) {
            Button(model.state.darkMode ? "Light Mode" : "Dark Mode") { model.toggleDarkMode() }
                .keyboardShortcut("d", modifiers: [.command, .shift])
        }
    }
}

private extension View {
    /// A single-key menu shortcut. On macOS it shows in the menu and handles the key; on iPadOS the
    /// keys are handled by `HardwareKeyHandler` instead, so the menu item is left without one.
    @ViewBuilder
    func plainKeyShortcut(_ key: KeyEquivalent) -> some View {
        #if os(macOS)
        keyboardShortcut(key, modifiers: [])
        #else
        self
        #endif
    }
}
