import SwiftUI

/// The main window: the session list on the left, the selected terminal on the right.
struct ContentView: View {
    let store: SessionStore

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 180, ideal: 230, max: 360)
        } detail: {
            SessionDetailView(store: store)
        }
        .frame(minWidth: 720, minHeight: 420)
    }
}
