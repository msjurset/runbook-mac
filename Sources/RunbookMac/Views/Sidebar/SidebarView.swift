import SwiftUI

struct SidebarView: View {
    @Environment(\.openSettings) private var openSettings
    @Binding var selection: SidebarItem?

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
            // The "+" moved to the runbook list's own filter bar — that's
            // the natural place for "new item in THIS list", matching Mail
            // / Notes / Reminders. Refresh moved to the View > Refresh
            // menu (⌘R) and is also unnecessary in normal use because
            // RunbookStore now watches the books directory via FSEvents.
            HStack(spacing: 12) {
                Button(action: { openSettings() }) {
                    Image(systemName: "gearshape")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings (⌘,)")
                .accessibilityIdentifier("toolbar.settings")

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .navigationTitle("Runbook")
    }
}
