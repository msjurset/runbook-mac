import SwiftUI

extension Notification.Name {
    /// Posted by the View > Refresh menu item. Listened to in ContentView,
    /// which calls store.loadAll(). The filesystem watcher catches most
    /// external changes automatically — this is the manual escape hatch
    /// for users who know they want to force a re-read.
    static let runbookRefreshRequested = Notification.Name("runbookRefreshRequested")
}

struct NavigateCommands: Commands {
    @FocusedValue(\.sidebarSelection) var sidebarSelection
    @FocusedValue(\.showQuickJump) var showQuickJump

    var body: some Commands {
        CommandMenu("Navigate") {
            Button("Runbooks") {
                sidebarSelection?.wrappedValue = .runbooks
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("History") {
                sidebarSelection?.wrappedValue = .history
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("Schedules") {
                sidebarSelection?.wrappedValue = .cron
            }
            .keyboardShortcut("3", modifiers: .command)

            Button("Repositories") {
                sidebarSelection?.wrappedValue = .pull
            }
            .keyboardShortcut("4", modifiers: .command)

            Divider()

            Button("Go to Runbook...") {
                showQuickJump?.wrappedValue = true
            }
            .keyboardShortcut("k", modifiers: .command)

            Divider()

            Button("Refresh") {
                NotificationCenter.default.post(
                    name: .runbookRefreshRequested, object: nil)
            }
            .keyboardShortcut("r", modifiers: .command)
        }
    }
}
