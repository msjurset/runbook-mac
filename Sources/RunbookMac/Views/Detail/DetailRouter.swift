import SwiftUI

struct DetailRouter: View {
    let selection: NavigationItem?

    var body: some View {
        switch selection {
        case .runbook(let book):
            RunbookDetailView(runbook: book)
        case .history:
            HistoryListView()
        case .cron:
            CronView()
        case .pull:
            PullView()
        case nil:
            ContentUnavailableView(
                "Select a Runbook",
                systemImage: "doc.text",
                description: Text("Choose a runbook from the sidebar or create a new one.")
            )
        }
    }
}
