import SwiftUI
import Frets2KeysCore

struct FretboardView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.layoutWidth) private var layoutWidth
    @Environment(\.instrumentFillHeight) private var fillHeight
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let fretboard: Fretboard
    let title: String

    /// Fret width: narrower on an upright iPhone so more frets fit across the screen.
    private var cellWidth: CGFloat {
        Device.isPhone && verticalSizeClass == .regular ? 44 : 56
    }
    private static let standardCellHeight: CGFloat = 40
    private static let footerRowHeight: CGFloat = 24

    /// A short space to fill (an iPhone held sideways): tighter padding, no fret-marker row, and
    /// note badges that shrink with the strings, so the whole neck fits without scrolling.
    private var isCompact: Bool { (fillHeight ?? .infinity) < 300 }

    private var padding: EdgeInsets {
        if isCompact { return EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12) }
        if fillHeight != nil { return EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16) }
        let wide = layoutWidth >= 600
        return EdgeInsets(top: wide ? 24 : 16, leading: wide ? 24 : 16, bottom: wide ? 18 : 10, trailing: wide ? 24 : 16)
    }

    private var footerRowHeight: CGFloat { isCompact ? 20 : Self.footerRowHeight }

    private var footerRowCount: CGFloat {
        let capoRow: CGFloat = model.state.anyCapoActive ? 1 : 0
        return (isCompact ? 1 : 2) + capoRow
    }

    /// String spacing: fixed normally; when filling a height, as tall as fits (within reason).
    private var cellHeight: CGFloat {
        guard let fillHeight, !fretboard.tuning.isEmpty else { return Self.standardCellHeight }
        let available = fillHeight - padding.top - padding.bottom - footerRowCount * footerRowHeight
        return min(max(available / CGFloat(fretboard.tuning.count), isCompact ? 18 : 30), 52)
    }
    private static let singleMarkers: Set<Int> = [3, 5, 7, 9, 15, 17, 19, 21]
    private static let doubleMarkers: Set<Int> = [12, 24]
    private var frets: Range<Int> { 0..<(Tunings.fretCount + 1) }

    var body: some View {
        let context = model.state.noteLabelContext
        Card(padding: padding) {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Highest-pitched string on top, like looking down at the neck.
                    ForEach(Array(fretboard.tuning.enumerated().reversed()), id: \.offset) { stringIndex, openNote in
                        HStack(spacing: 0) {
                            ForEach(frets, id: \.self) { fret in
                                fretCell(openNote: openNote, stringNumber: fretboard.tuning.count - stringIndex, fret: fret, context: context)
                            }
                        }
                    }
                    VStack(spacing: 0) {
                        footerRow { fret in
                            Text(fret == 0 ? "" : "\(fret)")
                                .font(.system(size: 12))
                                .foregroundStyle(theme.fretNumber)
                        }
                        if !isCompact {
                            footerRow { fret in markers(for: fret) }
                        }
                        if fretboard.capo > 0 {
                            footerRow { fret in
                                Text(fret >= fretboard.capo ? "\(fret - fretboard.capo)" : "")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Tailwind.amber600)
                            }
                            .accessibilityLabel("Fret numbers relative to capo")
                        } else if model.state.anyCapoActive {
                            // Keeps both fretboards the same height when only the other has a capo.
                            footerRow { _ in Text(" ").font(.system(size: 12)) }
                                .accessibilityHidden(true)
                        }
                    }
                    .background { Rectangle().fill(theme.fretFooterBackground) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityIdentifier("instrument.\(title)")
    }

    @ViewBuilder
    private func fretCell(openNote: Note, stringNumber: Int, fret: Int, context: NoteLabelContext) -> some View {
        let note = openNote.transposed(by: fret)
        let isBelowCapo = fret < fretboard.capo
        let isSelected = model.state.isSelected(note) && !isBelowCapo
        let appearance = NoteAppearance(note: note, isSelected: isSelected, context: context)

        Button {
            model.toggle(note)
        } label: {
            Group {
                if case .selected(let role) = appearance.style {
                    // A selected fret is filled solid with its note's color, inset a little so
                    // neighboring selected frets stay separate.
                    NoteLabel(name: appearance.label, weight: .medium)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(NotePalette.solid(for: role), in: RoundedRectangle(cornerRadius: 4).inset(by: 1))
                } else {
                    HStack(spacing: 0) {
                        if !isBelowCapo {
                            stringLine
                            if appearance.showsLabel {
                                NoteBadge(appearance: appearance, size: min(20, cellHeight - 2))
                                stringLine
                            }
                        }
                    }
                }
            }
            .frame(width: cellWidth, height: cellHeight)
        }
        .buttonStyle(HighlightButtonStyle(highlighted: theme.subtleHover))
        .disabled(isBelowCapo)
        .overlay(alignment: .trailing) { fretDivider(fret: fret, color: theme.fretDivider) }
        .help(note.description)
        .accessibilityLabel("\(context.accessibilityName(for: note)), string \(stringNumber), fret \(fret)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var stringLine: some View {
        Rectangle()
            .fill(theme.stringLine)
            .frame(maxWidth: .infinity)
            .frame(height: 2)
    }

    private func footerRow<Content: View>(@ViewBuilder content: @escaping (Int) -> Content) -> some View {
        HStack(spacing: 0) {
            ForEach(frets, id: \.self) { fret in
                content(fret)
                    .frame(width: cellWidth, height: 16)
                    .padding(.vertical, (footerRowHeight - 16) / 2)
                    .overlay(alignment: .trailing) { fretDivider(fret: fret, color: theme.fretFooterDivider) }
            }
        }
    }

    private func fretDivider(fret: Int, color: Color) -> some View {
        let isCapoFret = fret == fretboard.capo
        return Rectangle()
            .fill(isCapoFret ? Tailwind.amber500 : color)
            .frame(width: isCapoFret ? 4 : 1)
    }

    @ViewBuilder
    private func markers(for fret: Int) -> some View {
        let dot = Circle().fill(theme.fretMarker).frame(width: 6, height: 6)
        if Self.doubleMarkers.contains(fret) {
            HStack(spacing: 4) { dot; dot }
        } else if Self.singleMarkers.contains(fret) {
            dot
        } else {
            Color.clear.frame(height: 6)
        }
    }
}
