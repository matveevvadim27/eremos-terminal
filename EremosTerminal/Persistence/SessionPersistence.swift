import Foundation

/// What's written to `sessions.json`. `version` lets a future format migrate old files.
struct SessionsFile: Codable, Equatable {
    var version = 1
    var sessions: [Session]
    var selectedID: UUID?
}

/// Reads and writes the session list. A struct with a file URL, so tests can point it at a temp folder.
struct SessionPersistence {
    let fileURL: URL

    /// `~/Library/Application Support/Eremos Terminal/sessions.json`
    static var standard: SessionPersistence {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return SessionPersistence(
            fileURL: support.appendingPathComponent("Eremos Terminal", isDirectory: true)
                .appendingPathComponent("sessions.json")
        )
    }

    /// nil when there's no file yet. A damaged file is set aside (not deleted) and the app starts empty.
    func load() -> SessionsFile? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        do {
            return try JSONDecoder().decode(SessionsFile.self, from: data)
        } catch {
            let backup = fileURL.deletingPathExtension().appendingPathExtension("broken.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            NSLog("Eremos Terminal: unreadable sessions.json moved to %@: %@", backup.path, String(describing: error))
            return nil
        }
    }

    func save(_ file: SessionsFile) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // Atomic: a crash mid-write never leaves a half-written file.
        try encoder.encode(file).write(to: fileURL, options: .atomic)
    }
}
