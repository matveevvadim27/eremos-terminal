import SwiftUI

/// The right side: a banner when the session needs an action, and the terminal under it.
struct SessionDetailView: View {
    let store: SessionStore

    var body: some View {
        if let session = store.selectedSession {
            VStack(spacing: 0) {
                // The banner is an optional first child, the terminal always the second: SwiftUI keeps the
                // terminal's host view (and thus the running terminal) when the banner comes and goes.
                if let banner = SessionBanner(session: session, store: store) {
                    banner
                    Divider()
                }
                TerminalContainerView(terminal: store.terminal(for: session.id))
            }
            .navigationTitle(session.name)
            .navigationSubtitle(session.displayPath)
        } else {
            ContentUnavailableView {
                Label("Нет открытых сессий", systemImage: "terminal")
            } description: {
                Text("Выберите папку — в ней откроется терминал и запустится Claude Code.")
            } actions: {
                Button("Новая сессия…") { store.presentNewSessionPanel() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}

private struct SessionBanner: View {
    let session: Session
    let store: SessionStore

    /// nil when the session needs nothing — the banner isn't shown at all.
    init?(session: Session, store: SessionStore) {
        switch session.status {
        case .restored, .folderMissing, .exited: break
        case .running: return nil
        }
        self.session = session
        self.store = store
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
            Text(message)
                .lineLimit(2)
            Spacer()
            actions
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
    }

    @ViewBuilder private var actions: some View {
        switch session.status {
        case .restored:
            Button("Новый claude") { store.startClaude(in: session.id, continueLast: false) }
            // No Return shortcut here: Return typed into the terminal would press the button instead.
            Button("Продолжить") { store.startClaude(in: session.id, continueLast: true) }
                .buttonStyle(.borderedProminent)
                .help("claude --continue — последний разговор в этой папке")
            dismissButton
        case .folderMissing:
            dismissButton
        case .exited:
            Button("Перезапустить") { store.restart(session.id) }
                .buttonStyle(.borderedProminent)
            Button("Закрыть сессию") { store.close(session.id) }
        case .running:
            EmptyView()
        }
    }

    private var dismissButton: some View {
        Button {
            store.dismissBanner(for: session.id)
        } label: {
            Image(systemName: "xmark")
        }
        .buttonStyle(.borderless)
        .help("Скрыть")
    }

    private var message: String {
        switch session.status {
        case .restored: "Сессия восстановлена. Продолжить последний разговор Claude?"
        case .folderMissing: "Папка \(session.displayPath) не найдена — терминал открыт в домашней папке."
        case .exited(let code): "Процесс завершился" + (code.map { " (код \($0))" } ?? "") + "."
        case .running: ""
        }
    }

    private var icon: String {
        switch session.status {
        case .restored: "arrow.clockwise.circle"
        case .folderMissing: "exclamationmark.triangle"
        default: "stop.circle"
        }
    }

    private var iconColor: Color {
        switch session.status {
        case .folderMissing: .orange
        case .exited: .red
        default: .accentColor
        }
    }
}
