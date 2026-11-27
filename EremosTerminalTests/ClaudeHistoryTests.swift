import XCTest
@testable import Eremos_Terminal

/// Finding Claude Code's conversations for a folder, the way Claude names its project folders.
final class ClaudeHistoryTests: XCTestCase {
    func testFolderPathIsEncodedLikeClaudeDoes() {
        XCTAssertEqual(ClaudeHistory.encode("/Users/me/Projects/my.app"), "-Users-me-Projects-my-app")
        XCTAssertEqual(ClaudeHistory.encode("/Users/me/Мои проекты"), "-Users-me-" + String(repeating: "-", count: 11))
    }

    func testConfigDirectoryComesFromEnvironment() {
        let url = ClaudeHistory.projectDirectory(for: "/tmp/x", environment: ["CLAUDE_CONFIG_DIR": "/opt/claude"])
        XCTAssertEqual(url.path, "/opt/claude/projects/-tmp-x")
    }

    func testFolderWithoutConversationsOffersNothing() {
        XCTAssertFalse(ClaudeHistory.hasConversations(in: "/nonexistent/\(UUID().uuidString)"))
    }
}
