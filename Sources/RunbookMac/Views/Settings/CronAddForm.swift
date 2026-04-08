import SwiftUI

struct CronAddForm: View {
    @Environment(RunbookStore.self) private var store
    @Binding var name: String
    @Binding var schedule: String
    @Binding var cronDescription: String
    let onAdd: () -> Void

    @FocusState private var isNameFocused: Bool
    @FocusState private var isScheduleFocused: Bool

    private var filteredRunbooks: [Runbook] {
        if name.isEmpty {
            return store.runbooks
        }
        return store.runbooks.filter {
            $0.name.localizedCaseInsensitiveContains(name)
        }
    }

    private var showSuggestions: Bool {
        guard isNameFocused else { return false }
        if store.runbooks.contains(where: { $0.name == name }) { return false }
        return !filteredRunbooks.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Row 1: Runbook name with autocomplete
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Runbook")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    FilterField(placeholder: "Name", text: $name)
                        .focused($isNameFocused)

                    if showSuggestions {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredRunbooks.prefix(8)) { book in
                                Button {
                                    name = book.name
                                    isNameFocused = false
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.text")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(book.name)
                                            .font(.body)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if book.id != filteredRunbooks.prefix(8).last?.id {
                                    Divider()
                                }
                            }
                        }
                        .background(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.quaternary)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    }
                }
                .frame(maxWidth: 250)

                Spacer()

                Button("Add") { onAdd() }
                    .disabled(name.isEmpty || schedule.isEmpty)
                    .controlSize(.large)
                    .padding(.top, 16)
            }

            // Row 2: Cron schedule with description + diagram
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Schedule")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    FilterField(placeholder: "e.g., 0 3 * * 0", text: $schedule)
                        .frame(maxWidth: 200)
                        .focused($isScheduleFocused)
                        .onChange(of: isScheduleFocused) { _, focused in
                            if !focused {
                                cronDescription = CronDescription.describe(schedule)
                            }
                        }
                        .onSubmit {
                            cronDescription = CronDescription.describe(schedule)
                        }

                    if !cronDescription.isEmpty {
                        Text(cronDescription)
                            .font(.callout)
                            .foregroundStyle(.orange)
                            .padding(.top, 2)
                    }
                }

                CronDiagram()
                    .padding(.top, 2)
            }
        }
        .padding()
    }
}

struct CronDiagram: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                Text("┌───────── minute (0-59)")
                Text("│ ┌─────── hour (0-23)")
                Text("│ │ ┌───── day of month (1-31)")
                Text("│ │ │ ┌─── month (1-12)")
                Text("│ │ │ │ ┌─ day of week (0-6, Sun=0)")
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)

            Text("* * * * *")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                cronLegendRow("*", "every value")
                cronLegendRow(",", "list: 1,3,5")
                cronLegendRow("-", "range: 1-5")
                cronLegendRow("/", "step: */15 (every 15)")
            }
        }
    }

    private func cronLegendRow(_ symbol: String, _ desc: String) -> some View {
        HStack(spacing: 6) {
            Text(symbol)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.orange)
                .frame(width: 16, alignment: .center)
            Text(desc)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
