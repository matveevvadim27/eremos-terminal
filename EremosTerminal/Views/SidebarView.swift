import SwiftUI

/// The left column: window buttons and the hide button, «Сессии» with the count and «+», the list, and
/// «Новая сессия» at the bottom.
struct SidebarView: View {
    let store: SessionStore
    /// The session whose name is being edited (like `const [renamingId, setRenamingId] = useState()`).
    @State private var renamingID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Top row: the window's red/yellow/green buttons are drawn by macOS on the left.
            HStack {
                Spacer()
                Button {
                    store.isSidebarVisible = false
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 15))
                }
                .buttonStyle(IconButtonStyle())
                .help("Скрыть боковую панель (⌃⌘S)")
            }
            .padding(.horizontal, 12)
            .frame(height: topBarHeight)
            .background(WindowDragArea())

            sectionHeader
                .background(WindowDragArea())

            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(Array(store.sessions.enumerated()), id: \.element.id) { index, session in
                        row(session, index: index)
                    }
                }
                .padding(.horizontal, 10)
            }
            .scrollIndicators(.never)
            .overlay(alignment: .topLeading) {
                if store.sessions.isEmpty {
                    Text("Пока пусто. Открытые сессии появятся здесь.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textMuted)
                        .padding(.horizontal, 22)
                        .padding(.top, 10)
                }
            }

            Button {
                store.addHomeSession()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.accent)
                    Text("Новая сессия")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    KeyCap("⌘T")
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(Theme.white(0.06), in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.white(0.08)))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Терминал в домашней папке")
            .padding(EdgeInsets(top: 12, leading: 12, bottom: 16, trailing: 12))
        }
        .background(
            LinearGradient(colors: [Theme.sidebarTop, Theme.sidebarBottom], startPoint: .top, endPoint: .bottom)
        )
        .overlay(alignment: .trailing) {
            Rectangle().fill(Theme.white(0.06)).frame(width: 1)
        }
    }

    /// «СЕССИИ 3» and the «+» menu: home folder or «Открыть папку…».
    private var sectionHeader: some View {
        HStack(spacing: 8) {
            Text("Сессии")
                .textCase(.uppercase)
                .font(.system(size: 11.5, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(Theme.textMuted)
            if !store.sessions.isEmpty {
                Text("\(store.sessions.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.keyText)
                    .padding(.horizontal, 5)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Theme.white(0.07), in: Capsule())
            }
            Spacer()
            Menu {
                Button("Новая сессия в домашней папке") { store.addHomeSession() }
                Button("Открыть папку…") { store.presentOpenFolderPanel() }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(IconButtonStyle())
            .fixedSize()
            .help("Новая сессия (⌘T) или выбрать папку (⌘O)")
        }
        .padding(EdgeInsets(top: 10, leading: 22, bottom: 8, trailing: 14))
    }

    private func row(_ session: Session, index: Int) -> some View {
        SessionRow(
            session: session,
            shortcutIndex: index < 9 ? index + 1 : nil,
            isSelected: store.selectedID == session.id,
            isRenaming: renamingID == session.id,
            onRename: { newName in finishRenaming(session.id, newName) },
            onCancelRename: { finishRenaming(nil, nil) }
        )
        // simultaneousGesture: the double click renames without delaying the single click (selection).
        .onTapGesture { store.selectedID = session.id }
        .simultaneousGesture(TapGesture(count: 2).onEnded { renamingID = session.id })
        .contextMenu {
            Button("Переименовать") { renamingID = session.id }
            Button("Показать в Finder") { store.revealInFinder(session.id) }
            Divider()
            Button("Закрыть сессию") { store.close(session.id) }
        }
    }

    /// `id` + name: save; nil: cancel. Either way the keyboard goes back to the terminal.
    private func finishRenaming(_ id: UUID?, _ newName: String?) {
        if let id, let newName { store.rename(id, to: newName) }
        renamingID = nil
        store.focusSelectedTerminal()
    }
}

private struct SessionRow: View {
    let session: Session
    let shortcutIndex: Int?
    let isSelected: Bool
    let isRenaming: Bool
    let onRename: (String) -> Void
    let onCancelRename: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            FolderTile(session: session, isSelected: isSelected)
            VStack(alignment: .leading, spacing: 3) {
                if isRenaming {
                    RenameField(initial: session.name, onCommit: onRename, onCancel: onCancelRename)
                } else {
                    Text(session.name)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(isSelected ? Color(hex: 0xFBF7F0) : Theme.text)
                        .lineLimit(1)
                }
                // "~" named "~" doesn't need its path repeated under the name.
                if session.displayPath != session.name {
                    Text(session.displayPath)
                        .font(Theme.mono)
                        .foregroundStyle(Theme.textMuted)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            Spacer(minLength: 4)
            if let attention = session.attention {
                AttentionMark(attention: attention)
            }
            if let shortcutIndex {
                KeyCap(
                    "⌘\(shortcutIndex)",
                    background: isSelected ? Theme.accent.opacity(0.22) : Theme.white(0.06),
                    foreground: isSelected ? Color(hex: 0xF5BBA4) : Theme.textMuted
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: 56)
        .background(background, in: RoundedRectangle(cornerRadius: 11))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.accent.opacity(0.34))
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .help(session.folderPath)
    }

    private var background: Color {
        if isSelected { return Theme.accent.opacity(0.14) }
        return hovering ? Theme.white(0.04) : .clear
    }
}

/// The folder icon of a row. A small dot in its corner tells what runs in the session:
/// green — Claude, red — the shell has quit, yellow — the folder is gone; no dot — just the shell.
private struct FolderTile: View {
    let session: Session
    let isSelected: Bool

    var body: some View {
        Image(systemName: "folder")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(isSelected ? Theme.onAccent : Theme.textSecondary)
            .frame(width: 34, height: 34)
            .background(isSelected ? Theme.accent : Theme.tile, in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                if !isSelected {
                    RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.white(0.06))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if let status {
                    Circle()
                        .fill(status.color)
                        .frame(width: 9, height: 9)
                        // A ring in the sidebar colour cuts the dot out of the tile's corner.
                        .padding(2)
                        .background(Theme.sidebarBottom, in: Circle())
                        .offset(x: 4, y: 4)
                        .help(status.hint)
                }
            }
    }

    private var status: (color: Color, hint: String)? {
        switch session.status {
        case .claude: (Theme.ok, "Claude работает")
        case .exited: (Theme.danger, "Терминал завершился")
        case .shell: session.folderMissing ? (Theme.warning, "Папка не найдена") : nil
        }
    }
}

/// The inline name editor: focused and selected on appear, Enter saves, Esc cancels, clicking away saves.
private struct RenameField: View {
    let onCommit: (String) -> Void
    let onCancel: () -> Void
    @State private var text: String
    @State private var done = false
    // @FocusState is the SwiftUI way to "autoFocus" a field (like `ref.current.focus()` in useEffect).
    @FocusState private var focused: Bool

    init(initial: String, onCommit: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.onCommit = onCommit
        self.onCancel = onCancel
        _text = State(initialValue: initial)
    }

    var body: some View {
        TextField("Название", text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13.5, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.accent.opacity(0.6)))
            .focused($focused)
            .onAppear { focused = true }
            .onSubmit { finish(save: true) }
            .onExitCommand { finish(save: false) }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { finish(save: true) }
            }
    }

    /// Runs once: Enter also takes the focus away, which would otherwise save a second time.
    private func finish(save: Bool) {
        guard !done else { return }
        done = true
        save ? onCommit(text) : onCancel()
    }
}

/// Claude finished (green check) or needs you (orange) while the session wasn't on screen.
private struct AttentionMark: View {
    let attention: Attention

    var body: some View {
        switch attention {
        case .finished:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.ok)
                .help("Claude закончил")
        case .needsInput:
            Image(systemName: "exclamationmark.bubble.fill")
                .foregroundStyle(Theme.accent)
                .help("Claude ждёт ответа")
        }
    }
}
