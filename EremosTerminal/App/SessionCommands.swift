import SwiftUI

/// Menu bar items and their shortcuts. In SwiftUI a shortcut is attached to a menu button, so it works
/// wherever the focus is — including inside the terminal.
struct SessionCommands: Commands {
    let store: SessionStore

    var body: some Commands {
        // Replaces File → New Window.
        CommandGroup(replacing: .newItem) {
            Button("Новая сессия") { store.addHomeSession() }
                .keyboardShortcut("t")
            Button("Открыть папку…") { store.presentOpenFolderPanel() }
                .keyboardShortcut("o")
            Button("Закрыть сессию") { store.closeSelected() }
                .keyboardShortcut("w")
                .disabled(store.selectedID == nil)
        }

        CommandMenu("Сессии") {
            // The toolbar buttons from the keyboard. Disabled while Claude runs, so the keys go to the terminal.
            Button("Новый Claude") { startClaude(.new) }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!canStartClaude)
            Button("Продолжить последний разговор") { startClaude(.continueLast) }
                .keyboardShortcut(.return, modifiers: [.command, .shift])
                .disabled(!canStartClaude)
            Button("Прошлые сессии Claude…") { startClaude(.pickPast) }
                .keyboardShortcut(.return, modifiers: [.command, .option])
                .disabled(!canStartClaude)

            Divider()

            ForEach(0..<9, id: \.self) { index in
                Button(title(at: index)) { store.select(index: index) }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")))
                    .disabled(index >= store.sessions.count)
            }
        }
    }

    private var canStartClaude: Bool {
        store.selectedID.map(store.canStartClaude(in:)) ?? false
    }

    private func startClaude(_ launch: ClaudeLaunch) {
        if let id = store.selectedID { store.startClaude(launch, in: id) }
    }

    private func title(at index: Int) -> String {
        index < store.sessions.count ? store.sessions[index].name : "Сессия \(index + 1)"
    }
}
