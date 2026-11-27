import SwiftUI

/// Menu bar items and their shortcuts. In SwiftUI a shortcut is attached to a menu button, so it works
/// wherever the focus is — including inside the terminal.
struct SessionCommands: Commands {
    let store: SessionStore

    var body: some Commands {
        // Replaces File → New Window.
        CommandGroup(replacing: .newItem) {
            Button("Новая сессия…") { store.presentNewSessionPanel() }
                .keyboardShortcut("t")
            Button("Закрыть сессию") { store.closeSelected() }
                .keyboardShortcut("w")
                .disabled(store.selectedID == nil)
        }

        CommandMenu("Сессии") {
            // The keyboard way to the «Продолжить» button of a restored session.
            Button("Продолжить разговор Claude") {
                if let id = store.selectedID { store.startClaude(in: id, continueLast: true) }
            }
            .keyboardShortcut(.return, modifiers: [.command, .shift])
            .disabled(store.selectedSession?.status != .restored)

            Divider()

            ForEach(0..<9, id: \.self) { index in
                Button(title(at: index)) { store.select(index: index) }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")))
                    .disabled(index >= store.sessions.count)
            }
        }
    }

    private func title(at index: Int) -> String {
        index < store.sessions.count ? store.sessions[index].name : "Сессия \(index + 1)"
    }
}
