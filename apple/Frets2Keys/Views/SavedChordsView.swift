import SwiftUI
import Frets2KeysCore

/// Lays children out left to right, wrapping onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let proposedWidth = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if proposedWidth > maxWidth && !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

struct SavedChordsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @State private var dropTargetID: UUID?

    var body: some View {
        let chords = model.state.savedChords
        if chords.isEmpty {
            Card {
                Text("No saved chords")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.mutedText)
                    .frame(maxWidth: .infinity)
            }
        } else {
            Card {
                FlowLayout(spacing: 8) {
                    ForEach(Array(chords.enumerated()), id: \.element.id) { index, chord in
                        chip(chord, index: index, count: chords.count)
                    }
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
