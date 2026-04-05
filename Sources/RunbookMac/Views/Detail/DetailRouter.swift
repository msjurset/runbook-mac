import SwiftUI

struct DetailRouter: View {
    let selection: NavigationItem?

    var body: some View {
        switch selection {
        case .runbook(let book):
            RunbookDetailView(runbook: book)
                .accessibilityIdentifier("detail.runbook")
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
                "Select a Runbook",
                systemImage: "doc.text",
                description: Text("Choose a runbook from the sidebar or create a new one.")
            )
            .accessibilityIdentifier("detail.empty")
        }
    }
}
