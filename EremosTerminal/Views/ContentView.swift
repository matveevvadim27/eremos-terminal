import SwiftUI

/// The main window: the session list on the left, the selected terminal on the right.
///
/// A plain HStack instead of `NavigationSplitView`: the design draws its own sidebar and header, and the window
/// has no title bar (`WindowChrome`) — so the layout is ours, like a flex row in CSS.
struct ContentView: View {
    let store: SessionStore

    var body: some View {
        HStack(spacing: 0) {
            if store.isSidebarVisible {
                SidebarView(store: store)
                    .frame(width: 272)
                    .transition(.move(edge: .leading))
            }
            SessionDetailView(store: store)
        }
        .animation(.easeOut(duration: 0.18), value: store.isSidebarVisible)
        .background(Theme.terminal)
        .foregroundStyle(Theme.text)
        // Content runs under the (transparent) title bar: the window buttons sit inside our top row.
        .ignoresSafeArea()
        .background(WindowChrome())
        .frame(minWidth: 720, minHeight: 420)
    }
}

/// Height of the top row (window buttons, header). The window's title bar is made exactly this tall.
let topBarHeight: CGFloat = 52

/// Room for the red/yellow/green window buttons at the left of the top row.
let windowButtonsWidth: CGFloat = 78
