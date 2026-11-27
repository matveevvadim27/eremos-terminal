import Foundation

/// Read-only look at Claude Code's own history: did Claude ever talk in this folder?
///
/// Claude keeps conversations in `~/.claude/projects/<folder path with every non-alphanumeric char → "-">/`
/// as `.jsonl` files (`CLAUDE_CONFIG_DIR` moves `~/.claude`). Used to offer «Продолжить» only where there is
/// something to continue.
enum ClaudeHistory {
    static func hasConversations(in folderPath: String) -> Bool {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: projectDirectory(for: folderPath).path) else {
            return false
        }
        return files.contains { $0.hasSuffix(".jsonl") }
    }

    static func projectDirectory(
        for folderPath: String,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        let config = environment["CLAUDE_CONFIG_DIR"].flatMap { $0.isEmpty ? nil : $0 }
            .map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath, isDirectory: true) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude", isDirectory: true)
        return config
            .appendingPathComponent("projects", isDirectory: true)
            .appendingPathComponent(encode(folderPath), isDirectory: true)
    }

    /// `/Users/me/my.app` → `-Users-me-my-app`.
    static func encode(_ folderPath: String) -> String {
        String(folderPath.map { $0.isASCII && ($0.isLetter || $0.isNumber) ? $0 : "-" })
    }
}
