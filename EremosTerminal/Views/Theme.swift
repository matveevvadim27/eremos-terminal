import AppKit
import SwiftUI

/// The design's tokens: a warm dark palette with one accent. Like a `theme.ts` with CSS variables —
/// views use these names, never raw hex values.
enum Theme {
    // Surfaces, darkest to lightest.
    static let terminal = Color(hex: 0x121110)
    static let header = Color(hex: 0x1A1917)
    static let sidebarTop = Color(hex: 0x211F1C)
    static let sidebarBottom = Color(hex: 0x1A1816)
    static let tile = Color(hex: 0x2B2825)

    // Text.
    static let textStrong = Color(hex: 0xF6F1E9)
    static let text = Color(hex: 0xEDE9E2)
    static let textSecondary = Color(hex: 0xA39E96)
    static let textMuted = Color(hex: 0x9B968E)
    static let textFaint = Color(hex: 0x8A857D)
    static let keyText = Color(hex: 0xB5B0A8)

    // Accent (Claude's orange) and states.
    static let accent = Color(hex: 0xE58A68)
    static let accentLight = Color(hex: 0xF0A183)
    static let onAccent = Color(hex: 0x1E130E)
    static let ok = Color(hex: 0x8FCB9B)
    static let warning = Color(hex: 0xE5C07B)
    static let danger = Color(hex: 0xE5786D)
    static let info = Color(hex: 0x7DB7DD)

    /// Hairlines and translucent fills over the dark surfaces.
    static func white(_ opacity: Double) -> Color { .white.opacity(opacity) }

    static let mono = Font.system(size: 11, design: .monospaced)
}

extension Color {
    /// `Color(hex: 0xE58A68)`, like `#E58A68` in CSS.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Small shared pieces

/// A keyboard shortcut chip: `⌘T`.
struct KeyCap: View {
    let text: String
    var background: Color = Theme.white(0.07)
    var foreground: Color = Theme.keyText

    init(_ text: String, background: Color = Theme.white(0.07), foreground: Color = Theme.keyText) {
        self.text = text
        self.background = background
        self.foreground = foreground
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(background, in: RoundedRectangle(cornerRadius: 6))
    }
}

/// The filled orange button (the main action on a screen).
struct AccentButtonStyle: ButtonStyle {
    var height: CGFloat = 32

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, 12)
            .frame(minHeight: height)
            .background(
                Theme.accent.opacity(configuration.isPressed ? 0.8 : 1),
                in: RoundedRectangle(cornerRadius: 9)
            )
            .contentShape(Rectangle())
    }
}

/// A quiet button: text on a transparent background that lights up on hover, like the header's «Закрыть».
struct GhostButtonStyle: ButtonStyle {
    var height: CGFloat = 32
    /// Draws a faint fill and border even without hover (secondary buttons next to an accent one).
    var bordered = false

    func makeBody(configuration: Configuration) -> some View {
        GhostButtonBody(configuration: configuration, height: height, bordered: bordered)
    }

    private struct GhostButtonBody: View {
        let configuration: Configuration
        let height: CGFloat
        let bordered: Bool
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(hovering ? Theme.text : Theme.textSecondary)
                .padding(.horizontal, 10)
                .frame(minHeight: height)
                .background(fill, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    if bordered {
                        RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.white(0.08))
                    }
                }
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
        }

        private var fill: Color {
            if configuration.isPressed { return Theme.white(0.12) }
            if hovering { return Theme.white(0.08) }
            return bordered ? Theme.white(0.05) : .clear
        }
    }
}

/// The square 32×32 icon button of the sidebar header.
struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        IconButtonBody(configuration: configuration)
    }

    private struct IconButtonBody: View {
        let configuration: Configuration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .foregroundStyle(hovering ? Theme.text : Theme.textSecondary)
                .frame(width: 32, height: 32)
                .background(
                    configuration.isPressed ? Theme.white(0.12) : hovering ? Theme.white(0.07) : .clear,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
        }
    }
}

/// An empty area that moves the window when dragged and zooms it on double click — like the title bar it
/// replaces. Put behind the header and the sidebar top (`.background(WindowDragArea())`).
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }

        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 {
                window?.performZoom(nil)
            } else {
                window?.performDrag(with: event)
            }
        }
    }
}
