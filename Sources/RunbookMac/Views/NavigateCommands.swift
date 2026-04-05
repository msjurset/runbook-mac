import SwiftUI

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
        }
    }
}
