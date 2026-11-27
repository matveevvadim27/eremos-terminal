import SwiftUI

/// Entry point, like the root `<App />` with its providers. The store is created once and lives as long as the
/// app: closing the window doesn't end the sessions — reopen it from the Dock or the «Окно» menu.
@main
struct EremosTerminalApp: App {
    // Bridge to AppKit's app delegate for what SwiftUI has no API for (see AppDelegate).
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = SessionStore()

    var body: some Scene {
        // `Window` (not `WindowGroup`): one main window — the sessions are the "tabs".
        Window("Eremos Terminal", id: "main") {
            ContentView(store: store)
                .onAppear {
                    appDelegate.openFolder = { [store] url in store.addSession(folder: url) }
                }
        }
        .commands {
            SessionCommands(store: store)
        }
    }
}
