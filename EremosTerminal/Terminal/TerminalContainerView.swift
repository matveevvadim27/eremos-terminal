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

/// A plain view that holds the current terminal, with padding around it in the terminal's colour.
final class TerminalHostView: NSView {
    // weak: the store owns the terminals; the host only displays one.
    private weak var current: LocalProcessTerminalView?
    /// Breathing room around the text, filled with the terminal's background colour.
    static let inset = NSEdgeInsets(top: 16, left: 24, bottom: 12, right: 16)
    private var inset: NSEdgeInsets { Self.inset }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override func updateLayer() {
        layer?.backgroundColor = NSColor(hex: 0x121110).cgColor
    }

    override var wantsUpdateLayer: Bool { true }

    func show(_ terminal: LocalProcessTerminalView?) {
        guard terminal !== current else { return }
        current?.removeFromSuperview()
        current = terminal
        guard let terminal else { return }
        addSubview(terminal)
        layoutTerminal()
        focusTerminal()
    }

    override func layout() {
        super.layout()
        layoutTerminal()
    }

    // Window resizes change the frame without always asking for layout(); the terminal must follow both.
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        layoutTerminal()
    }

    /// The terminal goes into the part of the host not covered by the toolbar (`safeAreaRect`), minus the
    /// padding, and gets a whole number of rows pinned to the top. Otherwise the leftover fraction of a row
    /// pushes the text up and the first line slides under the toolbar.
    /// The terminal recomputes rows × columns from its frame and tells the shell (SIGWINCH).
    private func layoutTerminal() {
        guard let terminal = current else { return }
        let safe = safeAreaRect
        let area = NSRect(
            x: safe.minX + inset.left,
            y: safe.minY + inset.bottom,
            width: max(0, safe.width - inset.left - inset.right),
            height: max(0, safe.height - inset.top - inset.bottom)
        )
        terminal.frame = area
        // After the frame is set the terminal knows its rows; trim the height to exactly those rows.
        let rowsHeight = min(area.height, terminal.getOptimalFrameSize().height)
        guard rowsHeight > 0, rowsHeight < area.height else { return }
        terminal.frame = NSRect(x: area.minX, y: area.maxY - rowsHeight, width: area.width, height: rowsHeight)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        needsLayout = true
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
