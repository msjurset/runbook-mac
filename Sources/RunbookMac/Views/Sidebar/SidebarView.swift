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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 12) {
                Button(action: { showNewRunbook = true }) {
                    Image(systemName: "plus")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("New Runbook")
                .accessibilityIdentifier("toolbar.newRunbook")

                Button(action: { store.loadAll() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Refresh")

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .navigationTitle("Runbook")
    }
}
