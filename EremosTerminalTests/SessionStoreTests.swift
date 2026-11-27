import XCTest
@testable import Eremos_Terminal

/// The list logic and persistence, without real shells (`startsProcesses: false`).
@MainActor
final class SessionStoreTests: XCTestCase {
    private var dir: URL!
    private var persistence: SessionPersistence!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        persistence = SessionPersistence(fileURL: dir.appendingPathComponent("sessions.json"))
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeStore() -> SessionStore {
        SessionStore(persistence: persistence, startsProcesses: false)
    }

    func testAddSelectsAndNamesByFolder() {
        let store = makeStore()
        store.addSession(folder: URL(fileURLWithPath: "/tmp/api"))
        store.addSession(folder: URL(fileURLWithPath: "/srv/api"))
        store.addSession(folder: URL(fileURLWithPath: "/tmp/web"))
        XCTAssertEqual(store.sessions.map(\.name), ["api", "api 2", "web"])
        XCTAssertEqual(store.selectedID, store.sessions[2].id)
    }

    func testSessionsSurviveRestart() {
        let store = makeStore()
        store.addSession(folder: URL(fileURLWithPath: "/tmp/one"))
        store.addSession(folder: URL(fileURLWithPath: "/tmp/two"))
        store.select(index: 0)

        let reopened = makeStore()
        XCTAssertEqual(reopened.sessions.map(\.name), ["one", "two"])
        XCTAssertEqual(reopened.sessions.map(\.folderPath), ["/tmp/one", "/tmp/two"])
        XCTAssertEqual(reopened.selectedID, store.sessions[0].id)
    }

    func testCloseSelectsNeighbour() {
        let store = makeStore()
        for name in ["a", "b", "c"] { store.addSession(folder: URL(fileURLWithPath: "/tmp/\(name)")) }
        store.select(index: 1)
        store.closeSelected()
        XCTAssertEqual(store.sessions.map(\.name), ["a", "c"])
        XCTAssertEqual(store.selectedSession?.name, "c")
        store.closeSelected()
        XCTAssertEqual(store.selectedSession?.name, "a")
        store.closeSelected()
        XCTAssertNil(store.selectedID)
        XCTAssertTrue(makeStore().sessions.isEmpty)
    }

    func testSelectIndexOutOfRangeKeepsSelection() {
        let store = makeStore()
        store.addSession(folder: URL(fileURLWithPath: "/tmp/a"))
        let selected = store.selectedID
        store.select(index: 5)
        XCTAssertEqual(store.selectedID, selected)
    }

    func testStatusIsNotSaved() throws {
        let file = SessionsFile(sessions: [Session(name: "x", folderPath: "/tmp/x", status: .exited(code: 1))])
        try persistence.save(file)
        let json = try String(contentsOf: persistence.fileURL, encoding: .utf8)
        XCTAssertFalse(json.contains("status"))
        XCTAssertEqual(persistence.load()?.sessions.first?.status, .shell)
    }

    func testBrokenFileIsSetAside() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("{oops".utf8).write(to: persistence.fileURL)
        XCTAssertTrue(makeStore().sessions.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("sessions.broken.json").path))
    }

    func testHomeSessionIsNamedTilde() {
        let store = makeStore()
        store.addHomeSession()
        store.addHomeSession()
        XCTAssertEqual(store.sessions.map(\.name), ["~", "~ 2"])
        XCTAssertEqual(store.sessions[0].folderPath, FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path)
    }

    func testRenameIsSavedAndEmptyNameRestoresDefault() {
        let store = makeStore()
        store.addSession(folder: URL(fileURLWithPath: "/tmp/api"))
        let id = store.sessions[0].id
        store.rename(id, to: "  Бекенд  ")
        XCTAssertEqual(store.sessions[0].name, "Бекенд")
        XCTAssertEqual(makeStore().sessions.first?.name, "Бекенд")

        store.rename(id, to: "   ")
        XCTAssertEqual(store.sessions[0].name, "api", "its own old name doesn't count as taken")
        XCTAssertEqual(makeStore().sessions.first?.name, "api")
    }
}
