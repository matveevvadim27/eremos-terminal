import SwiftUI

/// Entry point, like the root `<App />` with its providers. The store is created once and lives as long as the
/// app: closing the window doesn't end the sessions — reopen it from the Dock or the «Окно» menu.
@main
struct EremosTerminalApp: App {
    // Bridge to AppKit's app delegate for what SwiftUI has no API for (see AppDelegate).
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = Self.makeStore()

    /// Unit tests run inside a copy of the app: it must not open the real sessions (their shells) or rewrite
    /// the user's sessions.json, so under XCTest the store gets a throwaway file and no processes.
    private static func makeStore() -> SessionStore {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil else { return SessionStore() }
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("EremosTerminal-tests-\(UUID().uuidString).json")
        return SessionStore(persistence: SessionPersistence(fileURL: file), startsProcesses: false)
    }

    var body: some Scene {
        // `Window` (not `WindowGroup`): one main window — the sessions are the "tabs".
        Window("Eremos Terminal", id: "main") {
            ContentView(store: store)
                .onAppear {
                    appDelegate.openFolder = { [store] url in store.addSession(folder: url) }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SessionCommands(store: store)
        }
    }
}
