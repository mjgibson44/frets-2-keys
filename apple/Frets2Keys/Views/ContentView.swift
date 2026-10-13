import SwiftUI
import Frets2KeysCore

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var isFocused: Bool
    @State private var renameText = ""

    private var renameBinding: Binding<Bool> {
        Binding(get: { model.setBeingRenamed != nil }, set: { if !$0 { model.setBeingRenamed = nil } })
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { model.setPendingDeletion != nil }, set: { if !$0 { model.setPendingDeletion = nil } })
    }

    private var deleteTitle: String {
        let name = model.state.chordSets.first { $0.id == model.setPendingDeletion }?.name ?? "Set"
        return "Delete \u{201C}\(name)\u{201D}?"
    }

    var body: some View {
        @Bindable var model = model
        let theme = Theme(isDark: model.state.darkMode)

        GeometryReader { proxy in
            let width = proxy.size.width
            let padding: CGFloat = Device.isPhone ? 16 : (width >= 600 ? 32 : 24)

            // Top bar and chord panel stay put; the instruments scroll between them.
            VStack(spacing: 0) {
                HeaderView(instrumentChoice: phoneInstrumentChoice, instrumentOptions: instrumentOptions)
                    .padding(.horizontal, padding)
                    .padding(.top, Device.isPhone ? 4 : 16)
                    .padding(.bottom, 8)
                    .centered()

                GeometryReader { middle in
                    ScrollView(.vertical) {
                        instruments(width: width, availableHeight: middle.size.height - 16)
                            .padding(.horizontal, padding)
                            .padding(.vertical, 8)
                            .centered()
                    }
                }

                VStack(spacing: 8) {
                    chordLimitWarning
                    ChordPanel()
                }
                .padding(.horizontal, padding)
                .padding(.top, 8)
                .padding(.bottom, Device.isPhone ? 4 : 16)
                .centered()
                .animation(.easeInOut(duration: 0.2), value: model.showChordLimitWarning)
            }
            .environment(\.layoutWidth, width)
        }
        .background(theme.pageBackground.ignoresSafeArea())
        .foregroundStyle(theme.primaryText)
        .environment(\.theme, theme)
        .preferredColorScheme(model.state.darkMode ? .dark : .light)
        #if os(macOS)
        // On iOS the menu commands handle hardware keyboards; a focusable root view there would
        // summon the software keyboard.
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress(phases: .down, action: handleKeyPress)
        #else
        .background {
            HardwareKeyHandler(isActive: !model.isSheetPresented) { key in
                guard !model.isSheetPresented, let shortcut = Shortcut(key) else { return false }
                shortcut.perform(on: model)
                return true
            }
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
        #endif
        .inspector(isPresented: $model.isChordBankPresented) {
            ChordBankPicker()
                .environment(\.theme, theme)
                .environment(\.layoutWidth, 400)
                .preferredColorScheme(model.state.darkMode ? .dark : .light)
        }
        .sheet(isPresented: $model.isSettingsPresented, onDismiss: {
            if model.showTutorialAfterSettings {
                model.showTutorialAfterSettings = false
                model.isTutorialPresented = true
            }
        }) {
            SettingsView()
                .environment(\.theme, theme)
                .preferredColorScheme(model.state.darkMode ? .dark : .light)
        }
        .sheet(isPresented: $model.isTutorialPresented) {
            TutorialView()
                .environment(\.theme, theme)
                .preferredColorScheme(model.state.darkMode ? .dark : .light)
        }
        .alert("Rename Set", isPresented: renameBinding) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if let id = model.setBeingRenamed { model.renameSet(id, to: renameText) }
            }
        }
        .alert(deleteTitle, isPresented: deleteBinding) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let id = model.setPendingDeletion { model.deleteSet(id) }
            }
        } message: {
            Text("Its saved chords will be removed. This can't be undone.")
        }
        .onChange(of: model.setBeingRenamed) { _, id in
            if let id, let set = model.state.chordSets.first(where: { $0.id == id }) {
                renameText = set.name
            }
        }
        .onChange(of: instrumentOptions) { _, options in
            if !options.contains(phoneInstrument), let first = options.first { phoneInstrument = first }
        }
        .onChange(of: model.isSheetPresented) { _, presented in
            if !presented { isFocused = true }
        }
    }

    @ViewBuilder
    private var chordLimitWarning: some View {
        if model.showChordLimitWarning {
            ChordLimitWarning()
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Instruments

    /// On iPhone, which instrument is showing. Kept under its original key from when this was
    /// landscape-only.
    @AppStorage("landscapeInstrument") private var phoneInstrument = InstrumentChoice.guitar

    private var instrumentOptions: [InstrumentChoice] {
        InstrumentChoice.available(guitars: model.state.fretboards.count, piano: model.state.showPiano)
    }

    /// iPhone shows one instrument at a time; the toggle appears when there's more than one.
    private var phoneInstrumentChoice: Binding<InstrumentChoice>? {
        Device.isPhone ? $phoneInstrument : nil
    }

    /// The instrument to show on iPhone: the chosen one if it's turned on, otherwise the first available.
    private var phoneShowing: InstrumentChoice? {
        instrumentOptions.contains(phoneInstrument) ? phoneInstrument : instrumentOptions.first
    }

    @ViewBuilder
    private func instruments(width: CGFloat, availableHeight: CGFloat) -> some View {
        if Device.isPhone {
            let boards = model.state.fretboards
            // The instrument grows to fill the space between the bars, centered when it doesn't
            // need all of it.
            Group {
                switch phoneShowing {
                case .guitar where !boards.isEmpty:
                    FretboardView(fretboard: boards[0], title: "Guitar 1")
                case .guitar2 where boards.count > 1:
                    FretboardView(fretboard: boards[1], title: "Guitar 2")
                case .piano:
                    PianoView()
                default:
                    EmptyView()
                }
            }
            .environment(\.instrumentFillHeight, max(availableHeight, 160))
            .frame(minHeight: availableHeight)
        } else {
            VStack(spacing: 16) {
                fretboards(width: width)
                if model.state.showPiano {
                    PianoView()
                }
            }
        }
    }

    @ViewBuilder
    private func fretboards(width: CGFloat) -> some View {
        let boards = model.state.fretboards
        if !boards.isEmpty {
            // Side by side when there's room, like the web app; stacked on narrow screens.
            let layout = width >= 900 ? AnyLayout(HStackLayout(spacing: 16)) : AnyLayout(VStackLayout(spacing: 16))
            layout {
                ForEach(Array(boards.enumerated()), id: \.element.id) { index, board in
                    FretboardView(fretboard: board, title: "Guitar \(index + 1)")
                }
            }
        }
    }

    /// macOS keyboard shortcuts. Most are also menu commands (see `AppCommands`), which take priority;
    /// this also covers the alternate keys (+, _, forward delete).
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        guard press.modifiers.isDisjoint(with: [.command, .control, .option]), !model.isSheetPresented else {
            return .ignored
        }
        guard let shortcut = Shortcut(press) else { return .ignored }
        shortcut.perform(on: model)
        return .handled
    }
}

/// The web app's keyboard shortcuts.
enum Shortcut: CaseIterable {
    case clear, saveNew, update, transposeUp, transposeDown, play, loop, previous, next

    init?(_ press: KeyPress) {
        switch press.key {
        case .delete, .deleteForward: self = .clear
        case .return: self = .play
        case .space: self = .loop
        case .leftArrow: self = .previous
        case .rightArrow: self = .next
        default:
            switch press.characters.lowercased() {
            case "a": self = .saveNew
            case "s": self = .update
            case "+", "=": self = .transposeUp
            case "-", "_": self = .transposeDown
            default: return nil
            }
        }
    }

    @MainActor
    func perform(on model: AppModel) {
        switch self {
        case .clear: model.clearSelection()
        case .saveNew: model.saveAsNewChord()
        case .update: model.updateActiveChord()
        case .transposeUp: model.transpose(by: 1)
        case .transposeDown: model.transpose(by: -1)
        case .play: model.play()
        case .loop: model.toggleLoop()
        case .previous: model.selectPreviousChord()
        case .next: model.selectNextChord()
        }
    }
}

struct ChordLimitWarning: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("Maximum of \(AppState.maxSavedChords) chords reached. Delete some chords to save new ones.")
                .font(.system(size: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                model.dismissChordLimitWarning()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(HighlightButtonStyle(highlighted: theme.warningBorder.opacity(0.4), cornerRadius: 4))
            .accessibilityLabel("Dismiss")
        }
        .foregroundStyle(theme.warningText)
        .padding(12)
        .background(theme.warningBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(theme.warningBorder, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
