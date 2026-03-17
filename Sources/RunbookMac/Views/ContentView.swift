import SwiftUI

enum NavigationItem: Hashable {
    case runbook(Runbook)
    case history
    case cron
    case pull
}

struct ContentView: View {
    @Environment(RunbookStore.self) private var store
    @State private var selection: NavigationItem?
    @State private var showNewRunbook = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection, showNewRunbook: $showNewRunbook)
        } detail: {
            DetailRouter(selection: selection)
        }
        .sheet(isPresented: $showNewRunbook) {
            NewRunbookSheet { name, content in
                try store.saveRaw(content, to: "\(name).yaml")
                store.loadAll()
            }
        }
        .onAppear {
            store.loadAll()
        }
        .frame(minWidth: 800, minHeight: 500)
    }
}
