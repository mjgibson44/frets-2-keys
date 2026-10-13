import SwiftUI
import Frets2KeysCore

struct PianoView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.layoutWidth) private var layoutWidth
    @Environment(\.instrumentFillHeight) private var fillHeight
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Keys are narrower on an upright iPhone so more of the keyboard fits across the screen.
    private var isNarrow: Bool { Device.isPhone && verticalSizeClass == .regular }
    private var whiteKeyWidth: CGFloat { isNarrow ? 34 : 40 }
    private var blackKeyWidth: CGFloat { isNarrow ? 27 : 32 }

    /// iPad and Mac: how tall the card may grow, to line up with the guitars when there's room.
    /// It never shrinks below its usual size.
    var targetHeight: CGFloat?

    var body: some View {
        let wide = layoutWidth >= 600
        let notes = model.state.pianoNotes
        let whiteNotes = notes.filter { !$0.isBlackKey }
        let inset: CGFloat = fillHeight != nil ? 12 : (wide ? 24 : 16)
        let standardWhiteHeight: CGFloat = wide ? 144 : 112
        let whiteHeight: CGFloat = if let fillHeight {
            // Filling a height (iPhone) makes the keys as tall as the space allows.
            min(max(fillHeight - 2 * inset, 112), 300)
        } else if let targetHeight {
            max(targetHeight - 2 * inset, standardWhiteHeight)
        } else {
            standardWhiteHeight
        }
        let blackHeight: CGFloat = fillHeight == nil && whiteHeight == standardWhiteHeight ? (wide ? 80 : 56) : (whiteHeight * 0.56).rounded()

        Card(padding: EdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset)) {
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        ForEach(whiteNotes, id: \.self) { note in
                            whiteKey(note, height: whiteHeight)
                        }
                    }
                    ForEach(Array(whiteNotes.enumerated()), id: \.element) { index, whiteNote in
                        let blackNote = whiteNote.transposed(by: 1)
                        if blackNote.isBlackKey && notes.contains(blackNote) {
                            blackKey(blackNote, height: blackHeight)
                                .offset(x: CGFloat(index + 1) * whiteKeyWidth - blackKeyWidth / 2)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Piano")
        .accessibilityIdentifier("instrument.Piano")
    }

    private func appearance(for note: Note) -> NoteAppearance {
        NoteAppearance(
            note: note,
            isSelected: model.state.isSelected(note),
            key: model.state.selectedKey,
            keyLabelMode: model.state.keyLabelMode,
            noteLabelMode: model.state.noteLabelMode
        )
    }

    private func whiteKey(_ note: Note, height: CGFloat) -> some View {
        let appearance = appearance(for: note)
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4)
        return Button {
            model.toggle(note)
        } label: {
            VStack {
                Spacer(minLength: 0)
                if appearance.showsLabel {
                    keyLabel(appearance, plainTextColor: theme.pianoPlainText)
                }
            }
            .padding(.bottom, 8)
            .frame(width: whiteKeyWidth, height: height)
        }
        .buttonStyle(keyButtonStyle(appearance, normal: theme.whiteKey, highlighted: theme.whiteKeyHover))
        .clipShape(shape)
        // A filled key gets an edge in the card's color, separating it from a filled neighbor.
        .overlay(shape.strokeBorder(appearance.isSelected ? theme.cardBackground : theme.whiteKeyBorder, lineWidth: 1))
        .help(note.description)
        .accessibilityLabel("\(appearance.label)\(note.octave)")
        .accessibilityAddTraits(appearance.isSelected ? .isSelected : [])
    }

    private func blackKey(_ note: Note, height: CGFloat) -> some View {
        let appearance = appearance(for: note)
        return Button {
            model.toggle(note)
        } label: {
            VStack {
                Spacer(minLength: 0)
                if appearance.showsLabel {
                    keyLabel(appearance, plainTextColor: theme.blackKeyPlainText)
                }
            }
            .padding(.bottom, 4)
            .frame(width: blackKeyWidth, height: height)
        }
        .buttonStyle(keyButtonStyle(appearance, normal: theme.blackKey, highlighted: theme.blackKeyHover))
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4))
        // Sets the key apart from the white keys around it, which matters when both are filled.
        // Its top edge sits just above the keyboard, where the scroll view clips it off.
        .overlay {
            UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4)
                .strokeBorder(theme.cardBackground, lineWidth: 1.5)
                .padding(.top, -2)
        }
        .help(note.description)
        .accessibilityLabel("\(appearance.label)\(note.octave)")
        .accessibilityAddTraits(appearance.isSelected ? .isSelected : [])
    }

    /// A selected key is filled with its note's color, so its label needs no square of its own.
    @ViewBuilder
    private func keyLabel(_ appearance: NoteAppearance, plainTextColor: Color) -> some View {
        if appearance.isSelected {
            NoteLabel(name: appearance.label, weight: .medium)
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
        } else {
            NoteBadge(appearance: appearance, size: 20, plainTextColor: plainTextColor)
        }
    }

    private func keyButtonStyle(_ appearance: NoteAppearance, normal: Color, highlighted: Color) -> HighlightButtonStyle {
        guard case .selected(let role) = appearance.style else {
            return HighlightButtonStyle(normal: normal, highlighted: highlighted, cornerRadius: 4)
        }
        let solid = NotePalette.solid(for: role)
        return HighlightButtonStyle(normal: solid, highlighted: solid.opacity(0.85), cornerRadius: 4)
    }
}
