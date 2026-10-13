import SwiftUI
import Frets2KeysCore

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var isFocused: Bool
    @State private var renameText = ""
    @State private var sectionRenameText = ""
    /// The section's current name, shown as the placeholder.
    @State private var sectionRenamePlaceholder = ""

    private var renameBinding: Binding<Bool> {
        Binding(get: { model.setBeingRenamed != nil }, set: { if !$0 { model.setBeingRenamed = nil } })
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { model.setPendingDeletion != nil }, set: { if !$0 { model.setPendingDeletion = nil } })
    }

    private var sectionRenameBinding: Binding<Bool> {
        Binding(get: { model.sectionBeingRenamed != nil }, set: { if !$0 { model.sectionBeingRenamed = nil } })
    }

    private var sectionDeleteBinding: Binding<Bool> {
        Binding(get: { model.sectionPendingDeletion != nil }, set: { if !$0 { model.sectionPendingDeletion = nil } })
    }

    private var sectionDeleteTitle: String {
        let sections = model.state.activeSet.sections
        let index = sections.firstIndex { $0.id == model.sectionPendingDeletion }
        let name = index.map { sections[$0].displayName(index: $0) } ?? "Section"
        return "Delete \u{201C}\(name)\u{201D}?"
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

                if Device.isPhone {
                    instrumentPages(padding: padding)
                } else {
                    ScrollView(.vertical) {
                        VStack(spacing: 16) {
                            fretboards(width: width)
                                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { fretboardsHeight = $0 }
                            if model.state.showPiano {
                                PianoView(targetHeight: pianoTargetHeight)
                            }
                        }
                        .padding(.horizontal, padding)
                        .padding(.vertical, Self.instrumentsVerticalPadding)
                        .centered()
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { instrumentsAreaHeight = $0 }
                }

                // Floating glass cards: the selected chord (when there is one) above the chord set.
                VStack(spacing: 8) {
                    chordLimitWarning
                    ChordPanel()
                }
                .padding(.horizontal, Device.isPhone ? 10 : padding)
                .padding(.top, 8)
                .padding(.bottom, Device.isPhone ? 2 : 12)
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
        .alert("Rename Section", isPresented: sectionRenameBinding) {
            TextField(sectionRenamePlaceholder, text: $sectionRenameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if let id = model.sectionBeingRenamed { model.renameSection(id, to: sectionRenameText) }
            }
        } message: {
            Text("For example Verse, Chorus or Bridge.")
        }
        .alert(sectionDeleteTitle, isPresented: sectionDeleteBinding) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let id = model.sectionPendingDeletion { model.deleteSection(id) }
            }
        } message: {
            Text("Its chords and scales will be removed. This can't be undone.")
        }
        .onChange(of: model.sectionBeingRenamed) { _, id in
            let sections = model.state.activeSet.sections
            if let id, let index = sections.firstIndex(where: { $0.id == id }) {
                // Numbered default names ("Section 2") are left out so typing replaces them.
                let name = sections[index].displayName(index: index)
                sectionRenamePlaceholder = name
                sectionRenameText = name.wholeMatch(of: /Section \d+/) == nil ? name : ""
            }
        }
        .onChange(of: model.setBeingRenamed) { _, id in
            if let id, let set = model.state.chordSets.first(where: { $0.id == id }) {
                renameText = set.name
            }
        }
        .onChange(of: instrumentOptions) { _, options in
            if !options.contains(phoneInstrument), let first = options.first {
                phoneInstrument = first
            }
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

    /// The tabs in the top bar (iPhone). Picking one shows that instrument.
    private var phoneInstrumentChoice: Binding<InstrumentChoice>? {
        guard Device.isPhone else { return nil }
        return Binding(
            get: { phoneShowing ?? .guitar },
            set: { phoneInstrument = $0 }
        )
    }

    /// The instrument to show on iPhone: the chosen one if it's turned on, otherwise the first available.
    private var phoneShowing: InstrumentChoice? {
        instrumentOptions.contains(phoneInstrument) ? phoneInstrument : instrumentOptions.first
    }

    /// iPhone: one instrument per page, filling the space between the bars. Swiping up or down
    /// moves to the next instrument, looping around; the tabs in the top bar follow along.
    private func instrumentPages(padding: CGFloat) -> some View {
        let options = instrumentOptions
        let index = Binding(
            get: { phoneShowing.flatMap { options.firstIndex(of: $0) } ?? 0 },
            set: { if options.indices.contains($0) { phoneInstrument = options[$0] } }
        )
        return GeometryReader { area in
            InstrumentPager(count: options.count, index: index) { pageIndex in
                instrumentPage(options[pageIndex])
                    .environment(\.instrumentFillHeight, max(area.size.height - 16, 120))
                    .padding(.horizontal, padding)
                    .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    private func instrumentPage(_ choice: InstrumentChoice) -> some View {
        let boards = model.state.fretboards
        switch choice {
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

    // iPad and Mac: measured so the piano can grow into spare room, up to a guitar's height.
    private static let instrumentsVerticalPadding: CGFloat = 8
    @State private var instrumentsAreaHeight: CGFloat = 0
    @State private var fretboardsHeight: CGFloat = 0
    @State private var fretboardCardHeight: CGFloat = 0

    /// As tall as a guitar card, or whatever's left below the guitars if that's less.
    private var pianoTargetHeight: CGFloat? {
        guard !model.state.fretboards.isEmpty, fretboardCardHeight > 0 else { return nil }
        let spare = instrumentsAreaHeight - 2 * Self.instrumentsVerticalPadding - fretboardsHeight - 16
        return min(fretboardCardHeight, spare)
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
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { fretboardCardHeight = $0 }
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
    case clear, saveNew, update, transposeUp, transposeDown, play, loop, previous, next, cycleLabels

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
            case "n": self = .cycleLabels
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
        case .cycleLabels: model.cycleNoteLabels()
        }
    }
}

struct ChordLimitWarning: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("This set is full (\(AppState.maxSavedChords) chords and scales). Delete some to save new ones.")
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
        .background(theme.warningBackground, in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous).strokeBorder(theme.warningBorder, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
