import AppKit
import SwiftUI

/// Puts the window's red/yellow/green buttons into the middle of the design's 52 pt top row.
///
/// The window itself has no title bar (`.windowStyle(.hiddenTitleBar)` in the App): the content fills it and
/// clicks in the top row reach our buttons. macOS still places the window buttons for a 28 pt title bar, so
/// this view reaches its `NSWindow` (like using a ref to touch the DOM in `useEffect`), makes the title bar's
/// container as tall as our row and moves the buttons down. AppKit lays the title bar out again on resize and
/// on leaving full screen, so it's redone then.
struct WindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ChromeView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ChromeView: NSView {
        private var observers: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
            guard let window else { return }
            window.backgroundColor = NSColor(hex: 0x121110)
            let names: [Notification.Name] = [
                NSWindow.didResizeNotification,
                NSWindow.didEndLiveResizeNotification,
                NSWindow.didExitFullScreenNotification,
                NSWindow.didBecomeKeyNotification,
            ]
            observers = names.map { name in
                NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.placeWindowButtons() }
                }
            }
            placeWindowButtons()
            // SwiftUI finishes setting the window up after this view lands in it.
            DispatchQueue.main.async { [weak self] in self?.placeWindowButtons() }
        }

        private func placeWindowButtons() {
            guard let window, !window.styleMask.contains(.fullScreen),
                  let close = window.standardWindowButton(.closeButton),
                  let titlebar = close.superview, let container = titlebar.superview,
                  let frameView = container.superview
            else { return }

            container.frame = NSRect(
                x: 0, y: frameView.bounds.height - topBarHeight,
                width: frameView.bounds.width, height: topBarHeight
            )
            titlebar.frame = container.bounds

            let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
            for (index, type) in buttons.enumerated() {
                guard let button = window.standardWindowButton(type) else { continue }
                button.setFrameOrigin(NSPoint(
                    x: 20 + CGFloat(index) * 20,
                    y: ((topBarHeight - button.frame.height) / 2).rounded()
                ))
            }
        }

        deinit {
            observers.forEach(NotificationCenter.default.removeObserver)
        }
    }
}
