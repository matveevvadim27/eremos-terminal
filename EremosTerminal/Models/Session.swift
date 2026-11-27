import Foundation

/// One entry in the sidebar: a folder with its own shell, where Claude Code is started on demand.
///
/// Like a plain object in React state: only data, no behaviour. What's saved to disk is `id`, `name` and
/// `folderPath`; `status` and `folderMissing` describe the live process and are rebuilt on every launch.
struct Session: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var folderPath: String
    var status: SessionStatus = .shell
    /// The folder no longer exists: the shell was opened in the home folder instead.
    var folderMissing = false
    /// Claude finished or needs you while the session wasn't on screen; cleared when you open it.
    var attention: Attention?

    // Only these keys go to JSON. The runtime fields have default values, so decoding works without them.
    enum CodingKeys: String, CodingKey {
        case id, name, folderPath
    }

    init(id: UUID = UUID(), name: String, folderPath: String, status: SessionStatus = .shell) {
        self.id = id
        self.name = name
        self.folderPath = folderPath
        self.status = status
    }

    var folderURL: URL { URL(fileURLWithPath: folderPath, isDirectory: true) }

    /// `/Users/me/Projects/api` → `~/Projects/api`, for display.
    var displayPath: String { (folderPath as NSString).abbreviatingWithTildeInPath }
}

/// What's going on in the session's terminal. Updated by polling the shell's child processes (SessionStore).
/// A later stage can split `.claude` into "working" / "waiting for input" using Claude Code hooks.
enum SessionStatus: Hashable {
    /// The shell is at its prompt (or runs something else) — Claude can be started.
    case shell
    /// Claude Code is running in this session.
    case claude
    /// The shell has quit (e.g. `exit`); the scrollback is still visible.
    case exited(code: Int32?)
}

/// Why a session wants a look (a mark in the sidebar, a number on the Dock icon, a notification).
enum Attention: Hashable {
    case finished
    case needsInput
}

/// How to start Claude Code from the toolbar or the menu.
enum ClaudeLaunch {
    /// `claude` — a new conversation.
    case new
    /// `claude --continue` — the most recent conversation in this folder.
    case continueLast
    /// `claude --resume` — Claude's own list of past conversations in this folder, with search.
    case pickPast

    var command: String {
        switch self {
        case .new: "claude"
        case .continueLast: "claude --continue"
        case .pickPast: "claude --resume"
        }
    }
}
