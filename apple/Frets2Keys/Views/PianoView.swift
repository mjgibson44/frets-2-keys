import SwiftUI
import Frets2KeysCore

struct PianoView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.layoutWidth) private var layoutWidth

    private static let whiteKeyWidth: CGFloat = 40
    private static let blackKeyWidth: CGFloat = 32

    var body: some View {
        let wide = layoutWidth >= 600
        let notes = model.state.pianoNotes
        let whiteNotes = notes.filter { !$0.isBlackKey }
        let whiteHeight: CGFloat = wide ? 144 : 112
        let blackHeight: CGFloat = wide ? 80 : 56

        Card(padding: EdgeInsets(top: wide ? 24 : 16, leading: wide ? 24 : 16, bottom: wide ? 24 : 16, trailing: wide ? 24 : 16)) {
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
                                .offset(x: CGFloat(index + 1) * Self.whiteKeyWidth - Self.blackKeyWidth / 2)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Piano")
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
            .frame(width: Self.whiteKeyWidth, height: height)
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
                    NoteBadge(appearance: appearance, selectedSize: 24, unselectedSize: 16, plainTextColor: theme.blackKeyPlainText)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(.bottom, 4)
            .frame(width: Self.blackKeyWidth, height: height)
        }
        .buttonStyle(HighlightButtonStyle(normal: theme.blackKey, highlighted: theme.blackKeyHover, cornerRadius: 4))
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4))
        .help(note.description)
        .accessibilityLabel("\(appearance.label)\(note.octave)")
        .accessibilityAddTraits(appearance.isSelected ? .isSelected : [])
    }
}
