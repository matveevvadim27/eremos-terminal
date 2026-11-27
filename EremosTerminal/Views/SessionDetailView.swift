import SwiftUI

/// The right side: the header, a banner when the session needs an action, and the terminal under it.
struct SessionDetailView: View {
    let store: SessionStore

    var body: some View {
        VStack(spacing: 0) {
            SessionHeader(session: store.selectedSession, store: store)
            if let session = store.selectedSession {
                // The banner is an optional child before the terminal: SwiftUI keeps the terminal's host view
                // (and thus the running terminal) when the banner comes and goes.
                if let banner = SessionBanner(session: session, store: store) {
                    banner
                }
                TerminalContainerView(terminal: store.terminal(for: session.id))
            } else {
                EmptyStateView(store: store)
            }
        }
        .background(Theme.terminal)
    }
}

// MARK: - Header

/// 52 pt top row: the session's name and folder on the left; Claude's buttons and «Закрыть» on the right.
private struct SessionHeader: View {
    let session: Session?
    let store: SessionStore

    var body: some View {
        HStack(spacing: 12) {
            if !store.isSidebarVisible {
                // The sidebar's hide button lives here while it's hidden, right after the window buttons.
                Button {
                    store.isSidebarVisible = true
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 15))
                }
                .buttonStyle(IconButtonStyle())
                .help("Показать боковую панель (⌃⌘S)")
            }
            if let session {
                Text(session.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                if session.displayPath != session.name {
                    PathChip(path: session.displayPath)
                }
                Spacer(minLength: 12)
                ClaudeControls(session: session, store: store)
                Button {
                    store.close(session.id)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Закрыть")
                        KeyCap("⌘W", foreground: Theme.textSecondary)
                    }
                }
                .buttonStyle(GhostButtonStyle())
                .help("Закрыть сессию: шелл и всё, что в нём запущено, завершатся")
            } else {
                Spacer()
            }
        }
        .padding(.leading, store.isSidebarVisible ? 24 : windowButtonsWidth)
        .padding(.trailing, 14)
        .frame(height: topBarHeight)
        // The drag area above the colour, so clicks on empty parts of the header reach it.
        .background {
            ZStack {
                Theme.header
                WindowDragArea()
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.white(0.06)).frame(height: 1)
        }
    }
}

/// `📁 ~/Projects/app` in a soft pill.
private struct PathChip: View {
    let path: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder")
                .font(.system(size: 10))
            Text(path)
                .font(.system(size: 11.5, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.head)
        }
        .foregroundStyle(Theme.textSecondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(Theme.white(0.05), in: RoundedRectangle(cornerRadius: 7))
        .help(path)
    }
}

/// The Claude buttons while the shell is idle, a «Claude работает» mark while Claude runs (typing a command then
/// would go into Claude's prompt), nothing once the shell has quit.
private struct ClaudeControls: View {
    let session: Session
    let store: SessionStore

    var body: some View {
        switch session.status {
        case .shell:
            HStack(spacing: 8) {
                // «Прошлые сессии» + an arrow with «continue the last one», like a split button.
                HStack(spacing: 0) {
                    Button {
                        store.startClaude(.pickPast, in: session.id)
                    } label: {
                        Label("Прошлые сессии", systemImage: "clock.arrow.circlepath")
                    }
                    .buttonStyle(GhostButtonStyle(bordered: true))
                    .help("claude --resume — выбрать разговор из прошлых в этой папке (⌥⌘↩)")

                    Menu {
                        Button("Продолжить последний разговор  ⇧⌘↩") {
                            store.startClaude(.continueLast, in: session.id)
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .menuStyle(.button)
                    .menuIndicator(.hidden)
                    .buttonStyle(GhostButtonStyle(bordered: true))
                    .fixedSize()
                    .padding(.leading, 2)
                    .help("Продолжить последний разговор (⇧⌘↩)")
                }

                Button {
                    store.startClaude(.new, in: session.id)
                } label: {
                    HStack(spacing: 8) {
                        Text("✻").font(.system(size: 14))
                        Text("Новый Claude")
                        KeyCap("⌘↩", background: Theme.onAccent.opacity(0.14), foreground: Theme.onAccent)
                    }
                }
                .buttonStyle(AccentButtonStyle())
                .help("claude — новый разговор (⌘↩)")
            }
        case .claude:
            HStack(spacing: 7) {
                Circle()
                    .fill(Theme.ok)
                    .frame(width: 7, height: 7)
                Text("Claude работает")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.ok)
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Theme.ok.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            .help("Кнопки вернутся, когда Claude завершится")
        case .exited:
            EmptyView()
        }
    }
}

// MARK: - Banner

/// A strip under the header when the session wants an action: it was restored after a restart, its folder is
/// gone, or its shell has quit.
private struct SessionBanner: View {
    private enum Kind {
        case restored, folderMissing, exited(code: Int32?)
    }

    private let session: Session
    private let store: SessionStore
    private let kind: Kind

    /// nil when the session needs nothing — the banner isn't shown at all.
    init?(session: Session, store: SessionStore) {
        if case .exited(let code) = session.status {
            kind = .exited(code: code)
        } else if session.folderMissing {
            kind = .folderMissing
        } else if session.offersContinue, session.status == .shell {
            kind = .restored
        } else {
            return nil
        }
        self.session = session
        self.store = store
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.18), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.textStrong)
                Text(message)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color(hex: 0xB0AAA1))
                    .lineLimit(2)
            }
            Spacer(minLength: 16)
            actions
        }
        .padding(EdgeInsets(top: 10, leading: 24, bottom: 10, trailing: 16))
        .frame(minHeight: 64)
        .background(tint.opacity(0.07))
        .overlay(alignment: .bottom) {
            Rectangle().fill(tint.opacity(0.22)).frame(height: 1)
        }
    }

    // No Return shortcuts on these buttons: Return typed into the terminal would press them instead.
    @ViewBuilder private var actions: some View {
        switch kind {
        case .restored:
            Button {
                store.startClaude(.continueLast, in: session.id)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill").font(.system(size: 11))
                    Text("Продолжить")
                    Text("claude --continue")
                        .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Theme.onAccent.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
                }
                .padding(.horizontal, 4)
            }
            .buttonStyle(AccentButtonStyle(height: 40))
            .help("Продолжить последний разговор с Claude в этой папке (⇧⌘↩)")
            closeButton { store.dismissContinueOffer(for: session.id) }
        case .folderMissing:
            closeButton { store.dismissFolderWarning(for: session.id) }
        case .exited:
            Button("Перезапустить") { store.restart(session.id) }
                .buttonStyle(AccentButtonStyle(height: 36))
            Button("Закрыть сессию") { store.close(session.id) }
                .buttonStyle(GhostButtonStyle(height: 36, bordered: true))
        }
    }

    private func closeButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
        }
        .buttonStyle(IconButtonStyle())
        .help("Скрыть")
    }

    private var tint: Color {
        switch kind {
        case .restored: Theme.accent
        case .folderMissing: Theme.warning
        case .exited: Theme.danger
        }
    }

    private var icon: String {
        switch kind {
        case .restored: "arrow.counterclockwise"
        case .folderMissing: "exclamationmark.triangle"
        case .exited: "stop.circle"
        }
    }

    private var title: String {
        switch kind {
        case .restored: "Сессия восстановлена"
        case .folderMissing: "Папка не найдена"
        case .exited: "Терминал завершился"
        }
    }

    private var message: String {
        switch kind {
        case .restored:
            "Шелл открыт в папке проекта, Claude не запущен."
        case .folderMissing:
            "\(session.displayPath) больше нет — терминал открыт в домашней папке."
        case .exited(let code):
            (code.map { "Код выхода \($0). " } ?? "") + "История осталась на экране."
        }
    }
}

// MARK: - Empty state

private struct EmptyStateView: View {
    let store: SessionStore

    var body: some View {
        VStack(spacing: 28) {
            TerminalIllustration()
            VStack(spacing: 8) {
                Text("Нет открытых сессий")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.textStrong)
                Text("Откроется терминал в домашней или выбранной папке. Claude запускается кнопкой сверху.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 380)
            }
            HStack(spacing: 10) {
                Button {
                    store.addHomeSession()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus").font(.system(size: 13, weight: .bold))
                        Text("Новая сессия")
                        KeyCap("⌘T", background: Theme.onAccent.opacity(0.14), foreground: Theme.onAccent)
                    }
                    .font(.system(size: 14.5, weight: .semibold))
                    .padding(.horizontal, 8)
                }
                .buttonStyle(AccentButtonStyle(height: 46))

                Button {
                    store.presentOpenFolderPanel()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "folder").font(.system(size: 13))
                        Text("Открыть папку…")
                        KeyCap("⌘O", foreground: Theme.textSecondary)
                    }
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 6)
                }
                .buttonStyle(GhostButtonStyle(height: 46, bordered: true))
            }
            HStack(spacing: 20) {
                hint("⌘1–9", "переключить")
                hint("⌘↩", "новый Claude")
                hint("⌘W", "закрыть")
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func hint(_ key: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            KeyCap(key, background: Theme.white(0.06))
            Text(text)
        }
        .font(.system(size: 12))
        .foregroundStyle(Theme.textFaint)
    }
}

/// A tiny terminal window with a blinking-free cursor.
private struct TerminalIllustration: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(Color(hex: 0x4A4640)).frame(width: 7, height: 7)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background(Color(hex: 0x23211F))
            HStack(spacing: 8) {
                Text(">").font(.system(size: 16, design: .monospaced))
                Rectangle().frame(width: 9, height: 19)
                Spacer()
            }
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 16)
            .frame(maxHeight: .infinity)
        }
        .frame(width: 148, height: 112)
        .background(Theme.header)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.white(0.10)))
    }
}
