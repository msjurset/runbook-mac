import SwiftUI

enum SidebarItem: Hashable {
    case runbooks
    case history
    case cron
    case pull
}

struct ContentView: View {
    @Environment(RunbookStore.self) private var store
    @State private var sidebarSelection: SidebarItem? = .runbooks
    @State private var selectedRunbook: Runbook?
    @State private var showNewRunbook = false

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selection: $sidebarSelection,
                showNewRunbook: $showNewRunbook
            )
        } detail: {
            switch sidebarSelection {
            case .runbooks:
                RunbookBrowserView(selectedRunbook: $selectedRunbook)
            case .history:
                HistoryListView()
                    .accessibilityIdentifier("detail.history")
            case .cron:
                CronView()
                    .accessibilityIdentifier("detail.schedules")
            case .pull:
                PullView()
                    .accessibilityIdentifier("detail.repositories")
            case nil:
                ContentUnavailableView(
                    "Select a Section",
                    systemImage: "sidebar.left",
                    description: Text("Choose a section from the sidebar.")
                )
                .accessibilityIdentifier("detail.empty")
            }
        }
        .sheet(isPresented: $showNewRunbook) {
            NewRunbookSheet { name, content in
                try store.saveRaw(content, to: "\(name).yaml")
                store.loadAll()
            }
        }
        .onChange(of: sidebarSelection) {
            if sidebarSelection != .runbooks {
                selectedRunbook = nil
            }
        }
        .onAppear {
            store.loadAll()
        }
        .frame(minWidth: 900, minHeight: 500)
    }
}
