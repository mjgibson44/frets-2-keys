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

    var body: some View {
        let wide = layoutWidth >= 600
        let notes = model.state.pianoNotes
        let whiteNotes = notes.filter { !$0.isBlackKey }
        let inset: CGFloat = fillHeight != nil ? 12 : (wide ? 24 : 16)
        // Filling a height (iPhone landscape) makes the keys as tall as the space allows.
        let whiteHeight: CGFloat = fillHeight.map { min(max($0 - 2 * inset, 112), 300) } ?? (wide ? 144 : 112)
        let blackHeight: CGFloat = fillHeight == nil ? (wide ? 80 : 56) : (whiteHeight * 0.56).rounded()

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
                    NoteBadge(appearance: appearance, selectedSize: 28, unselectedSize: 20, plainTextColor: theme.pianoPlainText)
                        .frame(width: 28, height: 28)
                }
            }
            .padding(.bottom, 8)
            .frame(width: whiteKeyWidth, height: height)
        }
        .buttonStyle(HighlightButtonStyle(normal: theme.whiteKey, highlighted: theme.whiteKeyHover, cornerRadius: 4))
        .clipShape(shape)
        .overlay(shape.strokeBorder(theme.whiteKeyBorder, lineWidth: 1))
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
                    // Same size as the white keys' badges (selected capped to fit the narrower key).
                    let selectedSize = min(28, blackKeyWidth - 2)
                    NoteBadge(appearance: appearance, selectedSize: selectedSize, unselectedSize: 20, plainTextColor: theme.blackKeyPlainText)
                        .frame(width: selectedSize, height: selectedSize)
                }
            }
            .padding(.bottom, 4)
            .frame(width: blackKeyWidth, height: height)
        }
        .buttonStyle(HighlightButtonStyle(normal: theme.blackKey, highlighted: theme.blackKeyHover, cornerRadius: 4))
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4))
        .help(note.description)
        .accessibilityLabel("\(appearance.label)\(note.octave)")
        .accessibilityAddTraits(appearance.isSelected ? .isSelected : [])
    }
}
