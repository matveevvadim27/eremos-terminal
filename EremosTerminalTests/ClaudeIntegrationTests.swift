import XCTest
@testable import Eremos_Terminal

final class ClaudeIntegrationTests: XCTestCase {
    private var dir: URL!
    private var integration: ClaudeIntegration!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        integration = ClaudeIntegration(directory: dir)
        try integration.install()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testParsesHookLines() {
        XCTAssertEqual(ClaudeIntegration.parse("stop\t{\"session_id\":\"x\"}"), .finished)
        XCTAssertEqual(ClaudeIntegration.parse("prompt\t{}"), .working)
        XCTAssertEqual(
            ClaudeIntegration.parse("notification\t{\"message\":\"Claude needs your permission to use Bash\"}"),
            .needsInput(message: "Claude needs your permission to use Bash")
        )
        XCTAssertEqual(ClaudeIntegration.parse("notification\tnot json"), .needsInput(message: nil))
        XCTAssertNil(ClaudeIntegration.parse("something\t{}"))
    }

    func testSettingsDeclareTheThreeHooks() throws {
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: integration.settingsFile)) as? [String: Any]
        let hooks = try XCTUnwrap(json?["hooks"] as? [String: Any])
        XCTAssertEqual(Set(hooks.keys), ["Stop", "Notification", "UserPromptSubmit"])
    }

    /// Runs the hook command exactly as Claude would (sh, hook JSON on stdin) and reads the result back.
    func testHookCommandWritesAnEventTheAppReads() throws {
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: integration.settingsFile)) as! [String: Any]
        let hooks = json["hooks"] as! [String: [[String: Any]]]
        let command = (hooks["Notification"]![0]["hooks"] as! [[String: Any]])[0]["command"] as! String
        let sessionID = UUID()

        let sh = Process()
        sh.executableURL = URL(fileURLWithPath: "/bin/sh")
        sh.arguments = ["-c", command]
        sh.environment = integration.environment(sessionID: sessionID)
        let stdin = Pipe()
        sh.standardInput = stdin
        try sh.run()
        stdin.fileHandleForWriting.write(Data("{\n\"message\": \"Нужно разрешение\"\n}".utf8))
        try stdin.fileHandleForWriting.close()
        sh.waitUntilExit()
        XCTAssertEqual(sh.terminationStatus, 0)

        let events = integration.drainEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.sessionID, sessionID)
        XCTAssertEqual(events.first?.event, .needsInput(message: "Нужно разрешение"))
        XCTAssertTrue(integration.drainEvents().isEmpty, "events are taken once")
    }

    func testHookIsSilentOutsideTheApp() throws {
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: integration.settingsFile)) as! [String: Any]
        let hooks = json["hooks"] as! [String: [[String: Any]]]
        let command = (hooks["Stop"]![0]["hooks"] as! [[String: Any]])[0]["command"] as! String
        let sh = Process()
        sh.executableURL = URL(fileURLWithPath: "/bin/sh")
        sh.arguments = ["-c", command]
        sh.environment = [:]
        sh.standardInput = FileHandle.nullDevice
        try sh.run()
        sh.waitUntilExit()
        XCTAssertEqual(sh.terminationStatus, 0)
    }
}
