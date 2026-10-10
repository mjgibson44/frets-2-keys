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
        if isActive {
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

        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            var unhandled = Set<UIPress>()
            for press in presses {
                guard let key = press.key, onPress?(key) == true else {
                    unhandled.insert(press)
                    continue
                }
            }
            if !unhandled.isEmpty { super.pressesBegan(unhandled, with: event) }
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
