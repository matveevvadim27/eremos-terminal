import AppKit
import SwiftTerm

/// Creates terminal views and the shells inside them.
@MainActor
enum TerminalFactory {
    static let shell = "/bin/zsh"

    /// A terminal view running `zsh -l` in `directory`. Login shell (`-l`) reads ~/.zprofile, and since it's
    /// interactive it reads ~/.zshrc too — so PATH is the same as in Terminal.app, `claude` included.
    ///
    /// With `startCommand` the shell runs it first and then becomes a normal interactive shell
    /// (`zsh -l -i -c 'claude; exec zsh -l'`): quitting Claude leaves you at the prompt in the same folder.
    static func makeTerminal(
        directory: String,
        startCommand: String? = nil,
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
            args: startCommand.map { ["-l", "-i", "-c", "\($0); exec \(shell) -l"] } ?? ["-l"],
            environment: environment(),
            execName: "-zsh",
            currentDirectory: directory
        )
        return view
    }

    /// Typed into a running shell as if by the user.
    static func run(_ command: String, in terminal: LocalProcessTerminalView) {
        terminal.send(txt: command + "\r")
    }

    /// The app's environment adjusted for a terminal. Apps started from Finder get a minimal environment
    /// without a locale — without LANG, zsh and Claude Code would garble Cyrillic.
    static func environment() -> [String] {
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
        return env.map { "\($0.key)=\($0.value)" }
    }
}
