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
        // App Store screenshots: `-ScreenshotState <base64 JSON>` starts from that saved state, kept
        // apart from the real one and never synced, so demo content can't reach the user's iCloud.
        let arguments = ProcessInfo.processInfo.arguments
        if let flag = arguments.firstIndex(of: "-ScreenshotState"), arguments.indices.contains(flag + 1),
           let state = Data(base64Encoded: arguments[flag + 1]) {
            let suite = "Frets2KeysScreenshots"
            UserDefaults().removePersistentDomain(forName: suite)
            let defaults = UserDefaults(suiteName: suite)!
            defaults.set(state, forKey: "frets2keys_appState")
            let model = AppModel(defaults: defaults, syncWithICloud: false)
            // `-ScreenshotSelect "F3 A3 C4 E4"` selects a chord (the selection isn't saved), and
            // `-ScreenshotBank` opens the chord bank.
            if let select = arguments.firstIndex(of: "-ScreenshotSelect"), arguments.indices.contains(select + 1) {
                let notes = arguments[select + 1].split(separator: " ").compactMap { Note(parsing: String($0)) }
                model.state.select(notes: notes)
                model.state.activeChordID = model.state.savedChords.first { $0.notes == notes }?.id
            }
            model.isChordBankPresented = arguments.contains("-ScreenshotBank")
            #if os(macOS)
            // A 1440×900 window, which captures at the Mac App Store's 2880×1800. It's brought
            // forward without taking keyboard focus, so typing elsewhere doesn't reach it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let window = NSApp.windows.first(where: { $0.isVisible }) {
                    window.setFrame(NSRect(x: 80, y: 80, width: 1440, height: 900), display: true)
                    window.orderFrontRegardless()
                }
            }
            #endif
            return model
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
            Button(model.isLoopingSelection ? "Stop Repeating" : "Repeat Chord") { model.toggleSelectionLoop() }
                .plainKeyShortcut(.space)
                .disabled(!enabled || !(state.hasSelection || model.isLoopingSelection))
            Button(model.isLooping && model.loopingSectionID == nil && !model.isLoopingSelection ? "Stop Song" : "Play Song") { model.toggleSongLoop() }
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
            Button(model.isSongPanelPresented ? "Hide Song Structure" : "Show Song Structure") {
                model.isSongPanelPresented.toggle()
            }
            .keyboardShortcut("j", modifiers: .command)
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
        CommandMenu("Songs") {
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
