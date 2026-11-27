import Foundation

/// Something Claude Code reported through its hooks.
enum ClaudeEvent: Equatable {
    /// `Stop`: Claude finished its answer and waits for the next message.
    case finished
    /// `Notification`: Claude needs you — a permission request or a question. The text comes from Claude.
    case needsInput(message: String?)
    /// `UserPromptSubmit`: you sent a message, Claude is working again.
    case working
}

/// Connects the sessions' Claude Code to the app — without touching the user's own Claude or zsh settings.
///
/// 1. `claude-settings.json` holds hooks: on each event Claude runs a one-line `sh` command that appends a line
///    to `events/<session id>.events`. The app reads these files once a second (`drainEvents`).
/// 2. Shells start with `ZDOTDIR` pointing at the app's `zsh/` folder. Its `.zshenv` restores the user's ZDOTDIR
///    (so `.zprofile`, `.zshrc` and history stay the user's own), loads their `.zshenv` and defines a `claude`
///    function that adds `--settings <claude-settings.json>`. So notifications work for the toolbar buttons and
///    for a `claude` typed by hand alike. The same trick is used by VS Code and kitty for shell integration.
struct ClaudeIntegration {
    let directory: URL

    var settingsFile: URL { directory.appendingPathComponent("claude-settings.json") }
    var eventsDirectory: URL { directory.appendingPathComponent("events", isDirectory: true) }
    var zshDirectory: URL { directory.appendingPathComponent("zsh", isDirectory: true) }

    /// Writes the files. Called on every launch, so an app update also updates them.
    func install() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: eventsDirectory, withIntermediateDirectories: true)
        try fm.createDirectory(at: zshDirectory, withIntermediateDirectories: true)
        try settingsJSON().write(to: settingsFile, options: .atomic)
        try Data(Self.zshenv.utf8).write(to: zshDirectory.appendingPathComponent(".zshenv"), options: .atomic)
    }

    /// Variables for a session's shell (added to TerminalFactory's environment).
    func environment(sessionID: UUID) -> [String: String] {
        var env = [
            "ZDOTDIR": zshDirectory.path,
            "EREMOS_SESSION_ID": sessionID.uuidString,
            "EREMOS_EVENTS_DIR": eventsDirectory.path,
            "EREMOS_CLAUDE_SETTINGS": settingsFile.path,
        ]
        // The user's own ZDOTDIR, if any, so .zshenv can put it back.
        if let own = ProcessInfo.processInfo.environment["ZDOTDIR"], !own.isEmpty {
            env["EREMOS_USER_ZDOTDIR"] = own
        }
        return env
    }

    /// Takes the events written since the last call. A file is renamed before reading, so a hook writing at the
    /// same moment starts a new file instead of being lost.
    func drainEvents() -> [(sessionID: UUID, event: ClaudeEvent)] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: eventsDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        var result: [(UUID, ClaudeEvent)] = []
        for file in files where file.pathExtension == "events" {
            guard let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent) else {
                try? fm.removeItem(at: file)
                continue
            }
            let taken = file.appendingPathExtension("reading")
            guard (try? fm.moveItem(at: file, to: taken)) != nil else { continue }
            let text = (try? String(contentsOf: taken, encoding: .utf8)) ?? ""
            try? fm.removeItem(at: taken)
            for line in text.split(separator: "\n") {
                if let event = Self.parse(line) { result.append((id, event)) }
            }
        }
        return result
    }

    /// One line: `<event>\t<hook input JSON>`.
    static func parse<S: StringProtocol>(_ line: S) -> ClaudeEvent? {
        let parts = line.split(separator: "\t", maxSplits: 1)
        guard let name = parts.first else { return nil }
        switch name {
        case "stop":
            return .finished
        case "prompt":
            return .working
        case "notification":
            let json = parts.count > 1
                ? (try? JSONSerialization.jsonObject(with: Data(parts[1].utf8))) as? [String: Any]
                : nil
            return .needsInput(message: json?["message"] as? String)
        default:
            return nil
        }
    }

    // MARK: - File contents

    private func settingsJSON() throws -> Data {
        func hook(_ event: String) -> [[String: Any]] {
            // Appends `<event>\t<stdin JSON on one line>`; does nothing outside Eremos Terminal; never fails.
            let command = #"[ -n "$EREMOS_EVENTS_DIR" ] && { printf '%s\t' '"# + event
                + #"'; tr -d '\n'; echo; } >> "$EREMOS_EVENTS_DIR/$EREMOS_SESSION_ID.events"; exit 0"#
            return [["hooks": [["type": "command", "command": command]]]]
        }
        var notification = hook("notification")
        // Only when Claude actually waits for you: a permission request or a question. Not the "still idle"
        // reminder a minute after an answer — that one is already covered by `stop`.
        notification[0]["matcher"] = "permission_prompt|elicitation_dialog"
        let settings: [String: Any] = [
            "hooks": [
                "Stop": hook("stop"),
                "Notification": notification,
                "UserPromptSubmit": hook("prompt"),
            ],
        ]
        return try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
    }

    /// Subcommands (`claude mcp …`, `claude update`…) run without the extra settings.
    private static let zshenv = """
    # Written by Eremos Terminal on every launch — local edits are overwritten.
    # zsh reads this file because the app sets ZDOTDIR here. Put the user's ZDOTDIR back, so the rest of the
    # startup (.zprofile, .zshrc, history) is exactly the user's own, then load their .zshenv.
    if [[ -n "${EREMOS_USER_ZDOTDIR-}" ]]; then ZDOTDIR="$EREMOS_USER_ZDOTDIR"; else unset ZDOTDIR; fi
    unset EREMOS_USER_ZDOTDIR
    [[ -f "${ZDOTDIR:-$HOME}/.zshenv" ]] && source "${ZDOTDIR:-$HOME}/.zshenv"

    # `claude` with Eremos Terminal's hooks, so the app knows when Claude finishes or needs you.
    claude() {
      case "${1-}" in
        agents|attach|auth|auto-mode|doctor|gateway|import|install|logs|mcp|plugin|purge|respawn|rm|setup-token|stop|ultrareview|update)
          command claude "$@" ;;
        *)
          command claude --settings "$EREMOS_CLAUDE_SETTINGS" "$@" ;;
      esac
    }

    """
}
