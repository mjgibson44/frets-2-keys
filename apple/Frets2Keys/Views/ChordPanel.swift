import SwiftUI
import Frets2KeysCore

/// The bottom of the window: two glass cards. The selected chord and its controls (only while
/// notes are selected) sit above the chord set's saved chords.
struct ChordPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// A sideways iPhone has little height, so the saved chords share one scrolling row.
    private var usesSingleRow: Bool {
        Device.isPhone && verticalSizeClass == .compact
    }

    /// Upright on iPhone, saved chords wrap up to about three rows, then scroll within them.
    private static let phoneChipsMaxHeight: CGFloat = 3 * 37 + 2 * 8

    private var padding: CGFloat { Device.isPhone ? 14 : 16 }

    var body: some View {
        GlassCardGroup(spacing: 8) {
            VStack(spacing: 8) {
                if model.state.hasSelection {
                    SelectionBar()
                        .padding(.horizontal, padding)
                        .padding(.vertical, Device.isPhone ? 8 : 10)
                        .glassCard()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                setsCard
                    .glassCard()
            }
        }
        .animation(.snappy(duration: 0.25), value: model.state.hasSelection)
    }

    /// The set menu, Add Chord and the set's chords, sized to its content.
    @ViewBuilder
    private var setsCard: some View {
        if usesSingleRow {
            // One row: set menu, saved chords scrolling sideways, then Add.
            HStack(spacing: 8) {
                SetMenu()
                ScrollView(.horizontal, showsIndicators: false) {
                    SavedChordChips(layout: .row)
                        .padding(.vertical, 2)
                }
                AddChordButton(compact: true)
            }
            .padding(.horizontal, padding)
            .padding(.vertical, 8)
        } else {
            VStack(alignment: .leading, spacing: Device.isPhone ? 10 : 12) {
                HStack {
                    SetMenu()
                    Spacer(minLength: 0)
                    AddChordButton()
                }
                if Device.isPhone {
                    // Grows with the set until it hits the cap, then scrolls.
                    ViewThatFits(in: .vertical) {
                        SavedChordChips(layout: .wrapping)
                        ScrollView(.vertical) {
                            SavedChordChips(layout: .wrapping)
                        }
                        .scrollIndicators(.visible)
                    }
                    .frame(maxHeight: Self.phoneChipsMaxHeight)
                } else {
                    SavedChordChips(layout: .wrapping)
                }
            }
            .padding(padding)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Groups glass cards so they blend together and morph as cards appear (iOS 26 and macOS 26).
struct GlassCardGroup<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26, macOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

extension View {
    /// A floating Liquid Glass card, or a frosted material card before iOS 26 / macOS 26.
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 22) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26, macOS 26, *) {
            frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: shape)
        } else {
            frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: shape)
        }
    }
}

// MARK: - Add chord

/// Opens (or closes) the chord bank side panel.
private struct AddChordButton: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    /// Icon only, for the single-row iPhone layout.
    var compact = false

    var body: some View {
        Button {
            withAnimation { model.isChordBankPresented.toggle() }
        } label: {
            Label("Add Chord", systemImage: "plus")
                .labelStyle(AddChordLabelStyle(compact: compact))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.secondaryText)
                .padding(.horizontal, compact ? 0 : 10)
                .padding(.vertical, compact ? 0 : 5)
                .frame(minWidth: compact ? 36 : nil, minHeight: compact ? 36 : nil)
        }
        .buttonStyle(HighlightButtonStyle(
            normal: model.isChordBankPresented ? theme.chipActive : theme.pageChip,
            highlighted: theme.chipHover,
            cornerRadius: 6
        ))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(theme.pageChipBorder, lineWidth: 1))
        .help("Choose a chord from the chord bank")
        // The compact (icon-only) style still needs a spoken name.
        .accessibilityLabel("Add Chord")
        .accessibilityAddTraits(model.isChordBankPresented ? .isSelected : [])
    }
}

private struct AddChordLabelStyle: LabelStyle {
    let compact: Bool

    func makeBody(configuration: Configuration) -> some View {
        if compact {
            configuration.icon.font(.system(size: 15, weight: .semibold))
        } else {
            Label(configuration)
        }
    }
}

// MARK: - Set menu

/// Shows the active set's name; the menu switches between sets and manages them.
struct SetMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @State private var isHovered = false

    var body: some View {
        let state = model.state
        Menu {
            Section("Chord Sets") {
                ForEach(state.chordSets) { set in
                    Toggle(isOn: Binding(
                        get: { set.id == model.state.activeSetID },
                        set: { if $0 { model.selectSet(set.id) } }
                    )) {
                        Text(set.name)
                        Text(set.chords.count == 1 ? "1 chord" : "\(set.chords.count) chords")
                    }
                }
            }
            Divider()
            SetActions(model: model)
        } label: {
            HStack(spacing: 6) {
                Text(state.activeSet.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Tailwind.zinc500)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isHovered ? theme.hover : .clear, in: RoundedRectangle(cornerRadius: 6))
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
        .padding(.leading, -8)
        .accessibilityLabel("Chord set: \(state.activeSet.name)")
    }
}

/// New / rename / duplicate / delete, shared by the set menu and the Mac menu bar.
struct SetActions: View {
    let model: AppModel

    var body: some View {
        let active = model.state.activeSetID
        Button("New Set", systemImage: "plus") { model.createSet() }
        Button("Rename…", systemImage: "pencil") { model.setBeingRenamed = active }
        Button("Duplicate", systemImage: "plus.square.on.square") { model.duplicateSet(active) }
        Button("Delete…", systemImage: "trash", role: .destructive) { model.setPendingDeletion = active }
    }
}

// MARK: - Saved chord chips

private struct SavedChordChips: View {
    enum Layout { case wrapping, row }

    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @State private var dropTargetID: UUID?
    let layout: Layout

    var body: some View {
        let chords = model.state.savedChords
        if chords.isEmpty {
            Text("No saved chords")
                .font(.system(size: 14))
                .foregroundStyle(theme.mutedText)
                .frame(maxWidth: layout == .wrapping ? .infinity : nil, alignment: layout == .wrapping ? .center : .leading)
                .padding(.vertical, 4)
        } else {
            let container = layout == .row ? AnyLayout(HStackLayout(spacing: 8)) : AnyLayout(FlowLayout(spacing: 8))
            container {
                ForEach(Array(chords.enumerated()), id: \.element.id) { index, chord in
                    chip(chord, index: index, count: chords.count)
                }
            }
        }
    }

    private func chip(_ chord: SavedChord, index: Int, count: Int) -> some View {
        let isActive = chord.id == model.state.activeChordID
        let isDropTarget = chord.id == dropTargetID
        // Colored by the chord's root, like that note on the instruments (for the app's key).
        let role = chord.rootPitchClass.map { NoteAppearance.colorRole(for: Note(midi: 60 + $0), key: model.state.selectedKey) }

        return HStack(spacing: 8) {
            Text(chord.name)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .fixedSize()
            Button {
                model.deleteChord(chord.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isActive ? .white.opacity(0.85) : theme.icon)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(HighlightButtonStyle(highlighted: (isActive ? Color.white : theme.icon).opacity(0.2), cornerRadius: 4))
            .help("Delete chord")
            .accessibilityLabel("Delete \(chord.name)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .modifier(NoteTileStyle(
            role: role,
            isSelected: isActive,
            selectedColor: theme.chipActive,
            fillsWidth: false,
            cornerRadius: 4,
            neutralBorder: theme.pageChipBorder,
            showsColorBorder: false,
            neutralFill: theme.pageChip
        ))
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 4).stroke(Tailwind.blue500, lineWidth: 2)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 4))
        .onTapGesture { model.selectChord(chord.id) }
        .draggable(chord.id.uuidString) {
            Text(chord.name)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(theme.chip, in: RoundedRectangle(cornerRadius: 4))
        }
        .dropDestination(for: String.self) { items, _ in
            guard let idString = items.first, let draggedID = UUID(uuidString: idString) else { return false }
            withAnimation(.snappy) { model.moveChord(draggedID, to: chord.id) }
            return true
        } isTargeted: { targeted in
            if targeted {
                dropTargetID = chord.id
            } else if dropTargetID == chord.id {
                dropTargetID = nil
            }
        }
        .contextMenu {
            Button("Move Left", systemImage: "arrow.left") { model.shiftChord(chord.id, by: -1) }
                .disabled(index == 0)
            Button("Move Right", systemImage: "arrow.right") { model.shiftChord(chord.id, by: 1) }
                .disabled(index == count - 1)
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) { model.deleteChord(chord.id) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(chord.name)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { model.selectChord(chord.id) }
        .accessibilityAction(named: "Delete") { model.deleteChord(chord.id) }
        .accessibilityAction(named: "Move Left") { model.shiftChord(chord.id, by: -1) }
        .accessibilityAction(named: "Move Right") { model.shiftChord(chord.id, by: 1) }
    }
}

// MARK: - Selection bar

/// The current selection (chord name and notes) with the actions that apply to it.
private struct SelectionBar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.layoutWidth) private var layoutWidth
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        if Device.isPhone && verticalSizeClass == .regular {
            // Upright iPhone: the chord on one line, its controls spread across the next.
            VStack(alignment: .leading, spacing: 4) {
                summaryStrip
                controls(spread: true)
            }
        } else {
            // One row: a long chord's notes scroll sideways, the controls stay put.
            HStack(spacing: 8) {
                summaryStrip
                controls(spread: false)
            }
        }
    }

    private var summaryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            summary
                .padding(.vertical, 2)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }

    @ViewBuilder
    private var summary: some View {
        let state = model.state
        if state.hasSelection {
            HStack(spacing: 8) {
                if let chordName = state.chordName {
                    Text(chordName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                        .fixedSize()
                        .accessibilityLabel("Chord: \(chordName)")
                }
                HStack(spacing: 4) {
                    ForEach(state.selectedNotes, id: \.self) { note in
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
                }
                .fixedSize()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Selected notes: " + state.selectedNotes.map(\.description).joined(separator: ", "))
            }
        } else {
            // Short on phones so the hint and controls share one row.
            Text(layoutWidth >= 600 || verticalSizeClass == .regular ? "Tap notes to build a chord" : "Select notes")
                .font(.system(size: 13))
                .foregroundStyle(theme.mutedText)
                .lineLimit(1)
                .fixedSize()
        }
    }

    private func controls(spread: Bool) -> some View {
        let state = model.state
        let size: CGFloat = layoutWidth >= 600 && !spread ? 32 : 36
        return HStack(spacing: 0) {
            IconButton(symbol: ActionIcon.clear, help: "Clear selection (Delete)", size: size, isEnabled: state.hasSelection) {
                model.clearSelection()
            }
            IconButton(symbol: ActionIcon.update, help: "Update saved chord (S)", size: size, isEnabled: state.canUpdateActiveChord) {
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
        }
        // Spread across the line, or packed at the end of the single row.
        .environment(\.iconButtonFillsWidth, spread)
        .fixedSize(horizontal: !spread, vertical: true)
    }
}
