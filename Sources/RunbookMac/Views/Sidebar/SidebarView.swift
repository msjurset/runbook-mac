import SwiftUI

struct SidebarView: View {
    @Environment(RunbookStore.self) private var store
    @Binding var selection: NavigationItem?
    @Binding var showNewRunbook: Bool

    var body: some View {
        List(selection: $selection) {
            Section("Runbooks") {
                ForEach(store.runbooks) { book in
                    NavigationLink(value: NavigationItem.runbook(book)) {
                        Label(book.name, systemImage: "doc.text")
                    }
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            deleteRunbook(book)
                        }
                    }
                }
            }

            Section("Management") {
                NavigationLink(value: NavigationItem.history) {
                    Label("History", systemImage: "clock")
                }
                NavigationLink(value: NavigationItem.cron) {
                    Label("Schedules", systemImage: "calendar.badge.clock")
                }
                NavigationLink(value: NavigationItem.pull) {
                    Label("Repositories", systemImage: "arrow.down.circle")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Runbook")
        .toolbar {
            ToolbarItem {
                Button(action: { showNewRunbook = true }) {
                    Label("New Runbook", systemImage: "plus")
                }
            }
            ToolbarItem {
                Button(action: { store.loadAll() }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
    }

    private func deleteRunbook(_ book: Runbook) {
        try? store.delete(book)
        store.loadAll()
        if case .runbook(let selected) = selection, selected == book {
            selection = nil
        }
    }
}
