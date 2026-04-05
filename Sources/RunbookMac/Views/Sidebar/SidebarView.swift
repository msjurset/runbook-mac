import SwiftUI

struct SidebarView: View {
    @Environment(RunbookStore.self) private var store
    @Binding var selection: SidebarItem?
    @Binding var showNewRunbook: Bool

    var body: some View {
        List(selection: $selection) {
            NavigationLink(value: SidebarItem.runbooks) {
                Label("Runbooks", systemImage: "doc.text")
            }
            .accessibilityIdentifier("sidebar.runbooks")

            Section("Management") {
                NavigationLink(value: SidebarItem.history) {
                    Label("History", systemImage: "clock")
                }
                .accessibilityIdentifier("sidebar.history")
                NavigationLink(value: SidebarItem.cron) {
                    Label("Schedules", systemImage: "calendar.badge.clock")
                }
                .accessibilityIdentifier("sidebar.schedules")
                NavigationLink(value: SidebarItem.pull) {
                    Label("Repositories", systemImage: "arrow.down.circle")
                }
                .accessibilityIdentifier("sidebar.repositories")
            }
        }
        .accessibilityIdentifier("sidebar")
        .listStyle(.sidebar)
        .navigationTitle("Runbook")
        .toolbar {
            ToolbarItem {
                Button(action: { showNewRunbook = true }) {
                    Label("New Runbook", systemImage: "plus")
                }
                .accessibilityIdentifier("toolbar.newRunbook")
            }
            ToolbarItem {
                Button(action: { store.loadAll() }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
    }
}
