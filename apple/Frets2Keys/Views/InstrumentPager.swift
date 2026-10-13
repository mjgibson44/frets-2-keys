import SwiftUI

/// Vertical pages that loop: swipe up for the next page, down for the previous, wrapping around in
/// both directions. Only the current page and its neighbors exist, each placed exactly one page
/// height apart, so the current page is always centered in the available space.
struct InstrumentPager<Page: View>: View {
    let count: Int
    @Binding var index: Int
    @ViewBuilder let page: (Int) -> Page

    @State private var dragOffset: CGFloat = 0
    @State private var isDraggingVertically = false

    private func wrapped(_ value: Int) -> Int {
        guard count > 0 else { return 0 }
        return ((value % count) + count) % count
    }

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            ZStack {
                ForEach(count > 1 ? [-1, 0, 1] : [0], id: \.self) { offset in
                    page(wrapped(index + offset))
                        .frame(width: geometry.size.width, height: height)
                        .offset(y: CGFloat(offset) * height + dragOffset)
                        // Only the current page is reachable by VoiceOver and touches.
                        .accessibilityHidden(offset != 0)
                        .allowsHitTesting(offset == 0)
                }
            }
            .frame(width: geometry.size.width, height: height)
            .clipped()
            .contentShape(Rectangle())
            // Simultaneous so taps on notes and sideways scrolling of the fretboard keep working.
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        guard count > 1 else { return }
                        if !isDraggingVertically {
                            isDraggingVertically = abs(value.translation.height) > abs(value.translation.width)
                        }
                        if isDraggingVertically { dragOffset = value.translation.height }
                    }
                    .onEnded { value in
                        guard isDraggingVertically else { return }
                        isDraggingVertically = false
                        let projected = value.predictedEndTranslation.height
                        if dragOffset < -height / 4 || projected < -height / 2 {
                            move(by: 1, height: height)
                        } else if dragOffset > height / 4 || projected > height / 2 {
                            move(by: -1, height: height)
                        } else {
                            withAnimation(.snappy) { dragOffset = 0 }
                        }
                    }
            )
            .accessibilityElement(children: .contain)
            .accessibilityScrollAction { edge in
                switch edge {
                case .bottom: move(by: 1, height: height)
                case .top: move(by: -1, height: height)
                default: break
                }
            }
        }
    }

    /// Slides to the next (1) or previous (-1) page, then makes it the current one.
    private func move(by step: Int, height: CGFloat) {
        withAnimation(.snappy(duration: 0.25)) {
            dragOffset = -CGFloat(step) * height
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                index = wrapped(index + step)
                dragOffset = 0
            }
        }
    }
}
