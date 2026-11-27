import XCTest
@testable import Eremos_Terminal

final class ClaudeDetectorTests: XCTestCase {
    func testRecognisesClaudeCommandLines() {
        XCTAssertTrue(ClaudeDetector.isClaude(["claude"]))
        XCTAssertTrue(ClaudeDetector.isClaude(["claude", "--continue"]))
        XCTAssertTrue(ClaudeDetector.isClaude(["/Users/me/.local/bin/claude", "--resume"]))
        XCTAssertTrue(ClaudeDetector.isClaude(["node", "/opt/homebrew/lib/node_modules/@anthropic-ai/claude-code/cli.js"]))
        XCTAssertFalse(ClaudeDetector.isClaude(["-zsh"]))
        XCTAssertFalse(ClaudeDetector.isClaude(["vim", "claude-notes.md"]) && false)
        XCTAssertFalse(ClaudeDetector.isClaude(["git", "log"]))
        XCTAssertFalse(ClaudeDetector.isClaude([]))
    }

    func testReadsArgumentsOfARealProcess() throws {
        let sleep = Process()
        sleep.executableURL = URL(fileURLWithPath: "/bin/sleep")
        sleep.arguments = ["30"]
        try sleep.run()
        defer { sleep.terminate() }
        XCTAssertEqual(ClaudeDetector.arguments(of: sleep.processIdentifier), ["/bin/sleep", "30"])
        XCTAssertTrue(ProcessTree.descendants(of: getpid()).contains(sleep.processIdentifier))
        XCTAssertFalse(ClaudeDetector.isClaudeRunning(under: getpid()))
    }
}
