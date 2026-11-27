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
        // Without this the default colours are black on white regardless of the system appearance.
        view.nativeBackgroundColor = .textBackgroundColor
        view.nativeForegroundColor = .textColor
        view.startProcess(
            executable: shell,
            args: ["-l"],
            environment: environment(adding: extraEnvironment),
            execName: "-zsh",
            currentDirectory: directory
        )
        return view
    }

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
