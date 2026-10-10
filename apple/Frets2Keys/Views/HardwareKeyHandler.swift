#if os(iOS)
import SwiftUI
import UIKit

/// Receives hardware keyboard presses on iPhone and iPad. It holds first-responder status without
/// accepting text input, so it never brings up the on-screen keyboard.
struct HardwareKeyHandler: UIViewRepresentable {
    /// Whether to reclaim first responder (e.g. after a sheet with text fields closes).
    var isActive: Bool
    let onPress: (UIKey) -> Bool

    func makeUIView(context: Context) -> KeyCatcherView {
        let view = KeyCatcherView()
        view.onPress = onPress
        return view
    }

    func updateUIView(_ view: KeyCatcherView, context: Context) {
        view.onPress = onPress
        view.isActive = isActive
        if isActive && !view.isFirstResponder {
            DispatchQueue.main.async { view.becomeFirstResponder() }
        }
    }

    final class KeyCatcherView: UIView {
        var onPress: ((UIKey) -> Bool)?
        var isActive = true

        override var canBecomeFirstResponder: Bool { isActive }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil { becomeFirstResponder() }
        }

        /// Presses this view handled, so their later phases aren't forwarded either.
        private var handledPresses = Set<UIPress>()

        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            var unhandled = Set<UIPress>()
            for press in presses {
                if let key = press.key, onPress?(key) == true {
                    handledPresses.insert(press)
                } else {
                    unhandled.insert(press)
                }
            }
            if !unhandled.isEmpty { super.pressesBegan(unhandled, with: event) }
        }

        override func pressesChanged(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            let unhandled = presses.subtracting(handledPresses)
            if !unhandled.isEmpty { super.pressesChanged(unhandled, with: event) }
        }

        override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            finish(presses, with: event) { super.pressesEnded($0, with: $1) }
        }

        override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            finish(presses, with: event) { super.pressesCancelled($0, with: $1) }
        }

        private func finish(_ presses: Set<UIPress>, with event: UIPressesEvent?, forward: (Set<UIPress>, UIPressesEvent?) -> Void) {
            let unhandled = presses.subtracting(handledPresses)
            handledPresses.subtract(presses)
            if !unhandled.isEmpty { forward(unhandled, event) }
        }
    }
}

extension Shortcut {
    init?(_ key: UIKey) {
        guard key.modifierFlags.isDisjoint(with: [.command, .control, .alternate]) else { return nil }
        switch key.keyCode {
        case .keyboardDeleteOrBackspace, .keyboardDeleteForward: self = .clear
        case .keyboardReturnOrEnter, .keypadEnter: self = .play
        case .keyboardSpacebar: self = .loop
        case .keyboardLeftArrow: self = .previous
        case .keyboardRightArrow: self = .next
        default:
            switch key.charactersIgnoringModifiers.lowercased() {
            case "a": self = .saveNew
            case "s": self = .update
            case "+", "=": self = .transposeUp
            case "-", "_": self = .transposeDown
            default: return nil
            }
        }
    }
}
#endif
