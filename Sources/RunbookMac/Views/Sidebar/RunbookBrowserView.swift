import SwiftUI

struct RunbookBrowserView: View {
    @Binding var selectedRunbook: Runbook?

    var body: some View {
        HStack(spacing: 0) {
            RunbookListView(selectedRunbook: $selectedRunbook)
                .frame(width: 280)
            Divider()
            Group {
                if let runbook = selectedRunbook {
                    RunbookDetailView(runbook: runbook)
                        .accessibilityIdentifier("detail.runbook")
                } else {
                    ContentUnavailableView(
                        "Select a Runbook",
                        systemImage: "doc.text",
                        description: Text("Choose a runbook from the list.")
                    )
                    .accessibilityIdentifier("detail.empty")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
