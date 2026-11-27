import AppKit
import Observation
import SwiftTerm

/// The app's single source of truth: the session list, the selection and the live terminals.
///
/// `@Observable` is roughly a store with automatic subscriptions: a SwiftUI view that reads `sessions` re-renders
/// when it changes, like a component using a Zustand/MobX store. Properties marked `@ObservationIgnored` don't
/// trigger re-renders — the terminal views themselves are such state: they live here for the app's whole life
/// and are only shown or hidden, never recreated, so processes and scrollback survive switching.
@Observable
@MainActor
final class SessionStore {
    private(set) var sessions: [Session] = []

    var selectedID: UUID? {
        didSet { if selectedID != oldValue { save() } }
    }

    @ObservationIgnored private var terminals: [UUID: LocalProcessTerminalView] = [:]
    @ObservationIgnored private let persistence: SessionPersistence
    @ObservationIgnored private let startsProcesses: Bool
    @ObservationIgnored private lazy var events = TerminalEvents(store: self)
    @ObservationIgnored private var statusTimer: Timer?
    /// When Claude was last launched from a button: until it shows up in the process list (a moment later),
    /// polling must not flip the status back to `.shell` and re-enable the buttons.
    @ObservationIgnored private var launchedAt: [UUID: Date] = [:]

    /// - Parameter startsProcesses: false in unit tests — the list logic without real shells.
    init(persistence: SessionPersistence = .standard, startsProcesses: Bool = true) {
        self.persistence = persistence
        self.startsProcesses = startsProcesses
        restore()
        if startsProcesses { startStatusPolling() }
    }

    var selectedSession: Session? {
        sessions.first { $0.id == selectedID }
    }

    func terminal(for id: UUID) -> LocalProcessTerminalView? {
        terminals[id]
    }

    // MARK: - Commands

    /// A new session in `folder`: a shell opens there; Claude is started from the toolbar when needed.
    func addSession(folder: URL) {
        let session = Session(name: uniqueName(for: folder), folderPath: folder.standardizedFileURL.path)
        sessions.append(session)
        startShell(for: session.id)
        selectedID = session.id
        save()
    }

    /// Ends the session's processes and removes it. The neighbour below (or above) becomes selected.
    func close(_ id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        endProcesses(of: id)
        sessions.remove(at: index)
        if selectedID == id {
            selectedID = sessions.isEmpty ? nil : sessions[min(index, sessions.count - 1)].id
        }
        save()
    }

    func closeSelected() {
        if let selectedID { close(selectedID) }
    }

    /// ⌘1…⌘9 — like tabs in a browser.
    func select(index: Int) {
        guard sessions.indices.contains(index) else { return }
        selectedID = sessions[index].id
    }

    /// The toolbar / menu buttons: types the `claude` command into the session's shell.
    /// Only while the shell is idle — otherwise the text would land in whatever runs there (e.g. Claude's prompt).
    func startClaude(_ launch: ClaudeLaunch, in id: UUID) {
        guard let terminal = terminals[id], canStartClaude(in: id) else { return }
        TerminalFactory.run(launch.command, in: terminal)
        launchedAt[id] = Date()
        setStatus(.claude, for: id)
        terminal.window?.makeFirstResponder(terminal)
    }

    func canStartClaude(in id: UUID) -> Bool {
        sessions.first { $0.id == id }?.status == .shell
    }

    /// Hides the "folder not found" banner.
    func dismissFolderWarning(for id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].folderMissing = false
        if let terminal = terminals[id] { terminal.window?.makeFirstResponder(terminal) }
    }

    /// A new shell in the same folder after the old one quit. The old scrollback goes away.
    func restart(_ id: UUID) {
        endProcesses(of: id)
        startShell(for: id)
    }

    func revealInFinder(_ id: UUID) {
        guard let session = sessions.first(where: { $0.id == id }) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([session.folderURL])
    }

    /// Asks for a folder, then creates a session there.
    func presentNewSessionPanel() {
        let panel = NSOpenPanel()
        panel.title = "Папка для новой сессии"
        panel.prompt = "Открыть"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if let current = selectedSession?.folderURL {
            panel.directoryURL = current.deletingLastPathComponent()
        }
        let handler: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.addSession(folder: url)
        }
        // A sheet attached to the window when there is one, otherwise a standalone dialog.
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            panel.begin(completionHandler: handler)
        }
    }

    // MARK: - Process events (called by TerminalEvents)

    fileprivate func processTerminated(_ view: TerminalView, exitCode: Int32?) {
        guard let id = terminals.first(where: { $0.value === view })?.key else { return }
        setStatus(.exited(code: exitCode), for: id)
    }

    // MARK: - Internals

    private func startShell(for id: UUID) {
        guard startsProcesses, let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        let folderExists = FileManager.default.fileExists(atPath: sessions[index].folderPath)
        terminals[id] = TerminalFactory.makeTerminal(
            directory: folderExists ? sessions[index].folderPath : NSHomeDirectory(),
            delegate: events
        )
        sessions[index].status = .shell
        sessions[index].folderMissing = !folderExists
    }

    /// Once a second: is Claude running in each shell? Drives the sidebar dot and enables the Claude buttons
    /// again after Claude quits. Cheap — a few sysctl calls per session.
    private func startStatusPolling() {
        statusTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshStatuses() }
        }
    }

    private func refreshStatuses() {
        for index in sessions.indices {
            guard let terminal = terminals[sessions[index].id], terminal.process.running else { continue }
            if case .exited = sessions[index].status { continue }
            let id = sessions[index].id
            let running = ClaudeDetector.isClaudeRunning(under: terminal.process.shellPid)
            if running { launchedAt[id] = nil }
            if !running, let launched = launchedAt[id], Date().timeIntervalSince(launched) < 5 { continue }
            let status: SessionStatus = running ? .claude : .shell
            if sessions[index].status != status { sessions[index].status = status }
        }
    }

    /// Removes the terminal and ends its shell with everything running inside (see ProcessTree).
    private func endProcesses(of id: UUID) {
        guard let terminal = terminals.removeValue(forKey: id) else { return }
        let pid = terminal.process.shellPid
        if terminal.process.running {
            ProcessTree.hangUp(root: pid)
        }
        terminal.terminate()
    }

    private func setStatus(_ status: SessionStatus, for id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].status = status
    }

    /// The folder name, plus " 2", " 3"… when a session with that name already exists.
    private func uniqueName(for folder: URL) -> String {
        let base = folder.lastPathComponent.isEmpty ? folder.path : folder.lastPathComponent
        let taken = Set(sessions.map(\.name))
        guard taken.contains(base) else { return base }
        var n = 2
        while taken.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }

    private func restore() {
        guard let file = persistence.load() else { return }
        sessions = file.sessions
        for session in sessions {
            startShell(for: session.id)
        }
        selectedID = file.selectedID.flatMap { id in sessions.contains { $0.id == id } ? id : nil }
            ?? sessions.first?.id
    }

    private func save() {
        do {
            try persistence.save(SessionsFile(sessions: sessions, selectedID: selectedID))
        } catch {
            NSLog("Eremos Terminal: can't save sessions: %@", String(describing: error))
        }
    }
}

/// SwiftTerm reports process events through a delegate object (an AppKit pattern: a callback interface instead of
/// props like `onExit`). This small class forwards them to the store.
private final class TerminalEvents: NSObject, LocalProcessTerminalViewDelegate {
    private weak var store: SessionStore?

    @MainActor init(store: SessionStore) {
        self.store = store
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        // SwiftTerm calls this on the main queue; `assumeIsolated` tells the compiler so.
        MainActor.assumeIsolated {
            store?.processTerminated(source, exitCode: exitCode)
        }
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
}
