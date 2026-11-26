import SwiftUI
import Frets2KeysCore

struct PianoView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.layoutWidth) private var layoutWidth
    @Environment(\.instrumentFillHeight) private var fillHeight
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.nextChordHint) private var hint

    /// Keys are narrower on an upright iPhone so more of the keyboard fits across the screen.
    private var isNarrow: Bool { Device.isPhone && verticalSizeClass == .regular }
    private var baseWhiteKeyWidth: CGFloat { isNarrow ? 34 : 40 }
    /// iPad and Mac: keys widen from their usual width to fill the card exactly, so the keyboard
    /// ends flush with the card (and with the guitar's, at the shared maximum width).
    private var whiteKeyWidth: CGFloat {
        let count = model.state.pianoNotes.filter { !$0.isBlackKey }.count
        guard !Device.isPhone, count > 0, cardWidth > 0 else { return baseWhiteKeyWidth }
        return max(baseWhiteKeyWidth, cardWidth / CGFloat(count))
    }
    private var blackKeyWidth: CGFloat { (whiteKeyWidth * 0.8).rounded() }
    @State private var cardWidth: CGFloat = 0


    /// iPad and Mac: how tall the card may grow, to match the guitars when there's room.
    /// It never shrinks below its usual size.
    var targetHeight: CGFloat?

    var body: some View {
        let wide = layoutWidth >= 600
        let notes = model.state.pianoNotes
        let whiteNotes = notes.filter { !$0.isBlackKey }
        let context = model.state.noteLabelContext
        let standardWhiteHeight: CGFloat = wide ? 144 : 112
        let whiteHeight: CGFloat = if let fillHeight {
            // Filling a height (iPhone) makes the keys as tall as the space allows.
            min(max(fillHeight, 112), 300)
        } else if let targetHeight {
            max(targetHeight, standardWhiteHeight)
        } else {
            standardWhiteHeight
        }
        let blackHeight: CGFloat = fillHeight == nil && whiteHeight == standardWhiteHeight ? (wide ? 80 : 56) : (whiteHeight * 0.56).rounded()

        InstrumentCard {
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        ForEach(whiteNotes, id: \.self) { note in
                            whiteKey(note, height: whiteHeight, context: context)
                        }
                    }
                    ForEach(Array(whiteNotes.enumerated()), id: \.element) { index, whiteNote in
                        let blackNote = whiteNote.transposed(by: 1)
                        if blackNote.isBlackKey && notes.contains(blackNote) {
                            blackKey(blackNote, height: blackHeight, context: context)
                                .offset(x: CGFloat(index + 1) * whiteKeyWidth - blackKeyWidth / 2)
                        }
                    }
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { cardWidth = $0 }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Piano")
        .accessibilityIdentifier("instrument.Piano")
    }

    private func appearance(for note: Note, context: NoteLabelContext) -> NoteAppearance {
        NoteAppearance(note: note, isSelected: model.state.isSelected(note), context: context)
    }

    private func isSounding(_ note: Note) -> Bool {
        model.soundingNotes.contains(note)
    }

    /// The light fill marking a key in the next chord.
    private func previewColor(_ note: Note, context: NoteLabelContext) -> Color {
        theme.noteSolid(NoteAppearance.colorRole(for: note, key: context.key))
    }

    private func whiteKey(_ note: Note, height: CGFloat, context: NoteLabelContext) -> some View {
        let appearance = appearance(for: note, context: context)
        return Button {
            model.toggle(note)
        } label: {
            VStack {
                Spacer(minLength: 0)
                keyLabel(appearance, size: whiteKeyWidth - 8, plainTextColor: theme.pianoPlainText)
            }
            .padding(.bottom, 4)
            .frame(width: whiteKeyWidth, height: height)
            .keyFill(note, appearance, sounding: isSounding(note), previewed: hint.isPreviewed(note, isSelected: false), hint: hint, previewColor: previewColor(note, context: context), theme: theme)
        }
        .buttonStyle(HighlightButtonStyle(normal: theme.whiteKey, highlighted: theme.whiteKeyHover))
        // One line between neighboring keys. The keyboard's top and bottom edges are left to the
        // card's border, so they aren't doubled up.
        .overlay(alignment: .trailing) {
            Rectangle().fill(theme.whiteKeyBorder).frame(width: 1)
        }
        .help(note.description)
        .accessibilityLabel(context.accessibilityName(for: note))
        .accessibilityAddTraits(appearance.isSelected ? .isSelected : [])
    }

    /// A black key is its fill inside a 1pt ring in the white keys' line color. The ring sits
    /// behind the fill rather than being stroked over it, so a colored key's rounded corners don't
    /// pick up a muddy blend of the two.
    private static let blackKeyEdge: CGFloat = 1
    private static let blackKeyOuterShape = UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4)
    private static let blackKeyInnerShape = UnevenRoundedRectangle(bottomLeadingRadius: 3, bottomTrailingRadius: 3)

    private func blackKey(_ note: Note, height: CGFloat, context: NoteLabelContext) -> some View {
        let appearance = appearance(for: note, context: context)
        return Button {
            model.toggle(note)
        } label: {
            VStack {
                Spacer(minLength: 0)
                keyLabel(appearance, size: blackKeyWidth - 2 * Self.blackKeyEdge - 4, plainTextColor: theme.blackKeyPlainText)
            }
            .padding(.bottom, 3)
            .frame(width: blackKeyWidth - 2 * Self.blackKeyEdge, height: height - Self.blackKeyEdge)
            .keyFill(note, appearance, sounding: isSounding(note), previewed: hint.isPreviewed(note, isSelected: false), hint: hint, previewColor: previewColor(note, context: context), theme: theme)
        }
        .buttonStyle(HighlightButtonStyle(normal: theme.blackKey, highlighted: theme.blackKeyHover))
        .clipShape(Self.blackKeyInnerShape)
        .padding([.leading, .trailing, .bottom], Self.blackKeyEdge)
        .background(Self.blackKeyOuterShape.fill(theme.whiteKeyBorder))
        .help(note.description)
        .accessibilityLabel(context.accessibilityName(for: note))
        .accessibilityAddTraits(appearance.isSelected ? .isSelected : [])
    }

    /// The note's name near the bottom of a key: white on a selected key, otherwise its badge.
    @ViewBuilder
    private func keyLabel(_ appearance: NoteAppearance, size: CGFloat, plainTextColor: Color) -> some View {
        ZStack {
            if case .selected(let role) = appearance.style {
                NoteLabel(name: appearance.label, weight: .medium)
                    .foregroundStyle(theme.noteSolidText(role))
            } else if appearance.showsLabel {
                NoteBadge(appearance: appearance, size: 20, plainTextColor: plainTextColor)
            }
        }
        .frame(width: size, height: size)
    }
}

private extension View {
    /// Fills the whole key: with the note's color when it's selected, a light wash of it when it's
    /// in the next chord, and a brief shade while it sounds.
    func keyFill(_ note: Note, _ appearance: NoteAppearance, sounding: Bool, previewed: Bool, hint: NextChordHint, previewColor: Color, theme: Theme) -> some View {
        self
            .noteFlash(sounding)
            .background {
                if case .selected(let role) = appearance.style {
                    theme.noteSolid(role)
                }
            }
            .nextChordFill(!appearance.isSelected && previewed, hint: hint, color: previewColor, inset: 0, cornerRadius: 0)
    }
}
