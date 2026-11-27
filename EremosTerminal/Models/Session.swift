import Foundation

/// One entry in the sidebar: a folder with its own shell (and usually Claude Code) running in it.
///
/// Like a plain object in React state: only data, no behaviour. What's saved to disk is `id`, `name` and
/// `folderPath`; `status` describes the live process and is rebuilt on every launch.
struct Session: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var folderPath: String
    var status: SessionStatus = .running

    // Only these keys go to JSON. `status` has a default value, so decoding works without it.
    enum CodingKeys: String, CodingKey {
        case id, name, folderPath
    }

    init(id: UUID = UUID(), name: String, folderPath: String, status: SessionStatus = .running) {
        self.id = id
        self.name = name
        self.folderPath = folderPath
        self.status = status
    }

    var folderURL: URL { URL(fileURLWithPath: folderPath, isDirectory: true) }

    /// `/Users/me/Projects/api` → `~/Projects/api`, for display.
    var displayPath: String { (folderPath as NSString).abbreviatingWithTildeInPath }
}

/// State of the session's process. A later stage can add Claude-specific states (working / waiting for input)
/// fed by Claude Code hooks.
enum SessionStatus: Hashable {
    /// The shell is running; for a new session `claude` was started automatically.
    case running
    /// Reopened after an app restart: the shell is running, `claude` is offered via the «Продолжить» button.
    case restored
    /// The folder no longer exists: the shell was opened in the home folder instead.
    case folderMissing
    /// The shell has quit (e.g. `exit`); the scrollback is still visible.
    case exited(code: Int32?)
}
