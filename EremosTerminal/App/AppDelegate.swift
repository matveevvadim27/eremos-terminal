import AppKit

/// AppKit-level hooks SwiftUI has no API for.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set by the App once the store exists: folders opened before that wait in `pendingFolders`.
    @MainActor var openFolder: ((URL) -> Void)? {
        didSet {
            guard let openFolder else { return }
            pendingFolders.forEach(openFolder)
            pendingFolders.removeAll()
        }
    }

    @MainActor private var pendingFolders: [URL] = []

    /// The design is dark-only: menus, context menus and the folder dialog follow it too.
    @MainActor func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }

    /// A folder dropped on the Dock icon or passed to `open -a "Eremos Terminal" <folder>` → a new session.
    @MainActor func application(_ application: NSApplication, open urls: [URL]) {
        let folders = urls.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        if let openFolder {
            folders.forEach(openFolder)
        } else {
            pendingFolders += folders
        }
    }
}
