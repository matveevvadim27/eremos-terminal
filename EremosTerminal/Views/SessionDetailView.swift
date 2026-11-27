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
            .navigationSubtitle(session.displayPath == session.name ? "" : session.displayPath)
            .toolbar {
                ClaudeToolbar(session: session, store: store)
            }
        } else {
            ContentUnavailableView {
                Label("Нет открытых сессий", systemImage: "terminal")
            } description: {
                Text("Терминал в домашней папке или в выбранной. Claude запускается кнопкой сверху.")
            } actions: {
                Button("Новая сессия") { store.addHomeSession() }
                    .keyboardShortcut(.defaultAction)
                Button("Открыть папку…") { store.presentOpenFolderPanel() }
            }
        }
    }
}

/// Top-right: the Claude buttons while the shell is idle, a "Claude работает" mark while Claude runs (typing a
/// command then would go into Claude's prompt), nothing once the shell has quit.
private struct ClaudeToolbar: ToolbarContent {
    let session: Session
    let store: SessionStore

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            switch session.status {
            case .shell:
                Button {
                    store.startClaude(.new, in: session.id)
                } label: {
                    Label("Новый Claude", systemImage: "sparkles")
                }
                .labelStyle(.titleAndIcon)
                .help("claude — новый разговор (⌘↩)")

                // A split button: the main part opens Claude's list of past conversations, the arrow has
                // "continue the last one".
                Menu {
                    Button("Продолжить последний разговор") { store.startClaude(.continueLast, in: session.id) }
                } label: {
                    Label("Прошлые сессии", systemImage: "clock.arrow.circlepath")
                } primaryAction: {
                    store.startClaude(.pickPast, in: session.id)
                }
                .labelStyle(.titleAndIcon)
                .help("claude --resume — выбрать разговор из прошлых в этой папке (⌥⌘↩)")
            case .claude:
                ClaudeRunningMark()
            case .exited:
                EmptyView()
            }
        }
    }
}

private struct ClaudeRunningMark: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
            Text("Claude работает")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .help("Кнопки вернутся, когда Claude завершится")
    }
}

private struct SessionBanner: View {
    let session: Session
    let store: SessionStore

    /// nil when the session needs nothing — the banner isn't shown at all.
    init?(session: Session, store: SessionStore) {
        guard session.folderMissing || session.isExited else { return nil }
        self.session = session
        self.store = store
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.isExited ? "stop.circle" : "exclamationmark.triangle")
                .foregroundStyle(session.isExited ? .red : .orange)
            Text(message)
                .lineLimit(2)
            Spacer()
            if session.isExited {
                // No Return shortcut here: Return typed into the terminal would press the button instead.
                Button("Перезапустить") { store.restart(session.id) }
                    .buttonStyle(.borderedProminent)
                Button("Закрыть сессию") { store.close(session.id) }
            } else {
                Button {
                    store.dismissFolderWarning(for: session.id)
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("Скрыть")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var message: String {
        if case .exited(let code) = session.status {
            return "Терминал завершился" + (code.map { " (код \($0))" } ?? "") + "."
        }
        return "Папка \(session.displayPath) не найдена — терминал открыт в домашней папке."
    }
}

private extension Session {
    var isExited: Bool {
        if case .exited = status { return true }
        return false
    }
}
