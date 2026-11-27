import AppKit
import SwiftTerm
import SwiftUI

/// Puts an AppKit terminal view into SwiftUI.
///
/// `NSViewRepresentable` is the bridge from SwiftUI to AppKit, a bit like a React component that renders an
/// empty `<div ref>` and lets an imperative library draw inside it: `makeNSView` runs once (mount),
/// `updateNSView` on every re-render. The host view is created once; on re-render it only swaps which of the
/// store's terminals sits inside. Terminals are never recreated, so switching is instant and nothing is lost.
struct TerminalContainerView: NSViewRepresentable {
    let terminal: LocalProcessTerminalView?

    func makeNSView(context: Context) -> TerminalHostView {
        TerminalHostView()
    }

    func updateNSView(_ host: TerminalHostView, context: Context) {
        host.show(terminal)
    }
}

/// A plain view that holds the current terminal, stretched to its whole size.
final class TerminalHostView: NSView {
    // weak: the store owns the terminals; the host only displays one.
    private weak var current: LocalProcessTerminalView?
    /// Breathing room around the text, filled with the terminal's background colour.
    private let inset = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 4)

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
    }

    override var wantsUpdateLayer: Bool { true }

    func show(_ terminal: LocalProcessTerminalView?) {
        guard terminal !== current else { return }
        current?.removeFromSuperview()
        current = terminal
        guard let terminal else { return }
        terminal.frame = NSRect(
            x: inset.left, y: inset.bottom,
            width: max(0, bounds.width - inset.left - inset.right),
            height: max(0, bounds.height - inset.top - inset.bottom)
        )
        // Follows the host's size; the terminal recomputes rows × columns and tells the shell (SIGWINCH).
        terminal.autoresizingMask = [.width, .height]
        addSubview(terminal)
        focusTerminal()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        focusTerminal()
    }

    /// Typing goes to the terminal right after a session is picked, without clicking into it.
    /// Deferred: during a SwiftUI update the list may still grab focus after us.
    private func focusTerminal() {
        DispatchQueue.main.async { [weak self] in
            guard let terminal = self?.current, let window = terminal.window else { return }
            window.makeFirstResponder(terminal)
        }
    }
}
