import AppKit
import SwiftTerm

/// Creates terminal views and the shells inside them.
@MainActor
enum TerminalFactory {
    static let shell = "/bin/zsh"

    /// A terminal view running `zsh -l` in `directory`. Login shell (`-l`) reads ~/.zprofile, and since it's
    /// interactive it reads ~/.zshrc too — so PATH is the same as in Terminal.app, `claude` included.
    static func makeTerminal(
        directory: String,
        extraEnvironment: [String: String] = [:],
        delegate: LocalProcessTerminalViewDelegate
    ) -> LocalProcessTerminalView {
        let view = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        view.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        view.processDelegate = delegate
        applyTheme(to: view)
        view.startProcess(
            executable: shell,
            args: ["-l"],
            environment: environment(adding: extraEnvironment),
            execName: "-zsh",
            currentDirectory: directory
        )
        return view
    }

    /// The design's warm dark palette: background, text, an orange caret and 16 ANSI colours to match
    /// (prompts, `ls`, git and Claude Code's own colours use these).
    static func applyTheme(to view: TerminalView) {
        view.nativeBackgroundColor = NSColor(hex: 0x121110)
        view.nativeForegroundColor = NSColor(hex: 0xE6E1D8)
        view.caretColor = NSColor(hex: 0xE58A68)
        view.caretTextColor = NSColor(hex: 0x1E130E)
        view.selectedTextBackgroundColor = NSColor(hex: 0xE58A68).withAlphaComponent(0.3)
        view.installColors(ansiPalette.map { hex in
            SwiftTerm.Color(
                red8: UInt16((hex >> 16) & 0xFF),
                green8: UInt16((hex >> 8) & 0xFF),
                blue8: UInt16(hex & 0xFF)
            )
        })
    }

    /// black, red, green, yellow, blue, magenta, cyan, white — then their bright versions.
    private static let ansiPalette: [UInt32] = [
        0x2B2825, 0xE5786D, 0x8FCB9B, 0xE5C07B, 0x7DB7DD, 0xC79BD8, 0x7CC7C0, 0xD8D3CA,
        0x6B665F, 0xF0958B, 0xB4E2BD, 0xF0D49A, 0xA3CDEA, 0xDDB8E8, 0xA5DDD7, 0xF6F1E9,
    ]

    /// Typed into the shell as if by the user. Ctrl+U first clears whatever is half-typed at the prompt.
    static func run(_ command: String, in terminal: LocalProcessTerminalView) {
        terminal.send(txt: "\u{15}" + command + "\r")
    }

    /// The app's environment adjusted for a terminal. Apps started from Finder get a minimal environment
    /// without a locale — without LANG, zsh and Claude Code would garble Cyrillic.
    static func environment(adding extra: [String: String] = [:]) -> [String] {
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        env["TERM_PROGRAM"] = "EremosTerminal"
        if env["LANG"]?.isEmpty ?? true {
            env["LANG"] = "en_US.UTF-8"
        }
        if env["LC_CTYPE"]?.isEmpty ?? true {
            env["LC_CTYPE"] = "UTF-8"
        }
        // When the app itself is started from a Claude Code session (e.g. while developing), these would make
        // every `claude` inside think it's nested.
        for key in env.keys where key == "CLAUDECODE" || key.hasPrefix("CLAUDE_CODE_") {
            env.removeValue(forKey: key)
        }
        env.merge(extra) { _, new in new }
        return env.map { "\($0.key)=\($0.value)" }
    }
}
