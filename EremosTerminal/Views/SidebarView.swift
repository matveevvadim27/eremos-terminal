import SwiftUI

struct SidebarView: View {
    // @Bindable turns the store's properties into two-way bindings (`$store.selectedID`),
    // like passing `value` + `onChange` to a controlled input in one go.
    @Bindable var store: SessionStore

    var body: some View {
        List(selection: $store.selectedID) {
            ForEach(Array(store.sessions.enumerated()), id: \.element.id) { index, session in
                SessionRow(session: session, shortcutIndex: index < 9 ? index + 1 : nil)
                    .tag(session.id)
                    .contextMenu {
                        Button("Показать в Finder") { store.revealInFinder(session.id) }
                        Divider()
                        Button("Закрыть сессию") { store.close(session.id) }
                    }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if store.sessions.isEmpty {
                Text("Нет сессий")
                    .foregroundStyle(.secondary)
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    store.presentNewSessionPanel()
                } label: {
                    Label("Новая сессия", systemImage: "plus")
                }
                .help("Новая сессия (⌘T)")
            }
        }
    }
}

private struct SessionRow: View {
    let session: Session
    let shortcutIndex: Int?

    var body: some View {
        HStack(spacing: 8) {
            StatusDot(session: session)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .lineLimit(1)
                Text(session.displayPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer(minLength: 4)
            if let shortcutIndex {
                Text("⌘\(shortcutIndex)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .help(session.folderPath)
    }
}

/// Green — Claude is running, grey — just the shell, red — the shell has quit, orange — the folder is gone.
private struct StatusDot: View {
    let session: Session

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .help(hint)
    }

    private var color: Color {
        switch session.status {
        case .claude: .green
        case .exited: .red
        case .shell: session.folderMissing ? .orange : .secondary
        }
    }

    private var hint: String {
        switch session.status {
        case .claude: "Claude работает"
        case .exited: "Терминал завершился"
        case .shell: session.folderMissing ? "Папка не найдена" : "Терминал"
        }
    }
}
