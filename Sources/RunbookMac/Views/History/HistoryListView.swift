import SwiftUI

struct HistoryListView: View {
    @Environment(RunbookStore.self) private var store
    @State private var filterName = ""

    private var filteredRecords: [HistoryRecord] {
        if filterName.isEmpty {
            return store.historyRecords
        }
        return store.historyRecords.filter {
            $0.runbook_name.localizedCaseInsensitiveContains(filterName)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter by runbook name", text: $filterName)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()

            if filteredRecords.isEmpty {
                ContentUnavailableView(
                    "No Run History",
                    systemImage: "clock",
                    description: Text("Run a runbook to see its history here.")
                )
            } else {
                List(filteredRecords) { record in
                    HistoryRowView(record: record)
                }
            }
        }
        .navigationTitle("History")
        .onAppear { store.loadAll() }
    }
}

struct HistoryRowView: View {
    let record: HistoryRecord
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(record.steps) { step in
                    HStack {
                        Image(systemName: statusIcon(step.status))
                            .foregroundStyle(statusColor(step.status))
                            .frame(width: 16)
                        Text(step.name)
                            .font(.caption)
                        Spacer()
                        Text(step.duration)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    if let error = step.error, !error.isEmpty {
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .padding(.leading, 20)
                    }
                }
            }
            .padding(.vertical, 4)
        } label: {
            HStack {
                Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(record.success ? .green : .red)
                VStack(alignment: .leading) {
                    Text(record.runbook_name)
                        .fontWeight(.medium)
                    Text(record.started_at)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(record.step_count) steps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(record.duration)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statusIcon(_ status: String) -> String {
        switch status {
        case "success": "checkmark.circle.fill"
        case "failed": "xmark.circle.fill"
        case "skipped": "minus.circle"
        default: "circle"
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "success": .green
        case "failed": .red
        case "skipped": .gray
        default: .secondary
        }
    }
}
