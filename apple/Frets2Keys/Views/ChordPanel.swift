import SwiftUI
import Frets2KeysCore

/// The chord set's saved chords, with the current selection and its controls attached underneath.
struct ChordPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SetMenu()
                    Spacer(minLength: 0)
                    AddChordButton()
                }
                SavedChordChips()
            }
            .padding(16)

            Rectangle()
                .fill(theme.cardBorder)
                .frame(height: 1)

            SelectionBar()
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(theme.selectionBarBackground)
        }
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(theme.cardBorder, lineWidth: 1))
    }
}

// MARK: - Add chord

/// Opens (or closes) the chord bank side panel.
private struct AddChordButton: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        Button {
            withAnimation { model.isChordBankPresented.toggle() }
        } label: {
            Label("Add Chord", systemImage: "plus")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
        }
        .buttonStyle(HighlightButtonStyle(
            normal: model.isChordBankPresented ? theme.chipActive : theme.chip,
            highlighted: theme.chipHover,
            cornerRadius: 6
        ))
        .help("Choose a chord from the chord bank")
        .accessibilityAddTraits(model.isChordBankPresented ? .isSelected : [])
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
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @State private var dropTargetID: UUID?

    var body: some View {
        let chords = model.state.savedChords
        if chords.isEmpty {
            Text("No saved chords")
                .font(.system(size: 14))
                .foregroundStyle(theme.mutedText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        } else {
            FlowLayout(spacing: 8) {
                ForEach(Array(chords.enumerated()), id: \.element.id) { index, chord in
                    chip(chord, index: index, count: chords.count)
                }
            }
        }
    }

    private func chip(_ chord: SavedChord, index: Int, count: Int) -> some View {
        let isActive = chord.id == model.state.activeChordID
        let isDropTarget = chord.id == dropTargetID

        return HStack(spacing: 8) {
            Text(chord.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.secondaryText)
                .lineLimit(1)
                .fixedSize()
            Button {
                model.deleteChord(chord.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.icon)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(HighlightButtonStyle(highlighted: theme.isDark ? Tailwind.zinc500 : Tailwind.zinc300, cornerRadius: 4))
            .help("Delete chord")
            .accessibilityLabel("Delete \(chord.name)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isActive ? theme.chipActive : theme.chip)
        )
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: 4).strokeBorder(theme.chipActiveRing, lineWidth: 1)
            }
        }
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

    var body: some View {
        // One row when it fits; otherwise the controls drop below the notes.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                summary
                Spacer(minLength: 0)
                controls
            }
            VStack(alignment: .leading, spacing: 6) {
                summary
                HStack {
                    Spacer(minLength: 0)
                    controls
                }
            }
        }
    }

    @ViewBuilder
    private var summary: some View {
        let state = model.state
        if state.hasSelection {
            let limit = layoutWidth >= 600 ? 6 : 4
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
                .fixedSize()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Selected notes: " + state.selectedNotes.map(\.description).joined(separator: ", "))
            }
        } else {
            // Short on phones so the hint and controls share one row.
            Text(layoutWidth >= 600 ? "Tap notes to build a chord" : "Select notes")
                .font(.system(size: 13))
                .foregroundStyle(theme.mutedText)
                .lineLimit(1)
                .fixedSize()
        }
    }

    private var controls: some View {
        let state = model.state
        let size: CGFloat = layoutWidth >= 600 ? 32 : 36
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
        .fixedSize()
    }
}
