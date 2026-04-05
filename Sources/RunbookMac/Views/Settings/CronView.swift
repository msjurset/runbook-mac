import SwiftUI

struct CronView: View {
    struct ScheduleEntry: Identifiable {
        var id: String { "\(name)|\(schedule)" }
        var name: String
        var schedule: String
        var command: String
        var description: String
    }

    @Environment(RunbookStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @State private var output = ""
    @State private var schedules: [ScheduleEntry] = []
    @State private var isLoading = false
    @State private var showAdd = false
    @State private var newName = ""
    @State private var newSchedule = ""
    @State private var errorMessage: String?
    @FocusState private var isNameFocused: Bool
    @FocusState private var isScheduleFocused: Bool
    @State private var cronDescription = ""
    @State private var editingName: String?
    @State private var editSchedule = ""

    private var filteredRunbooks: [Runbook] {
        if newName.isEmpty {
            return store.runbooks
        }
        return store.runbooks.filter {
            $0.name.localizedCaseInsensitiveContains(newName)
        }
    }

    private var showSuggestions: Bool {
        guard isNameFocused else { return false }
        // Don't show if the name exactly matches a runbook
        if store.runbooks.contains(where: { $0.name == newName }) { return false }
        return !filteredRunbooks.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Scheduled Runbooks")
                    .font(.headline)
                Spacer()
                Button("Add Schedule", systemImage: "plus") {
                    showAdd.toggle()
                }
                Button("Refresh", systemImage: "arrow.clockwise") {
                    loadCronList()
                }
            }
            .padding()

            Divider()

            if showAdd {
                addScheduleForm
                Divider()
            }

            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
            }

            if schedules.isEmpty && !isLoading {
                ContentUnavailableView(
                    "No Schedules",
                    systemImage: "calendar.badge.clock",
                    description: Text("Add a cron schedule to run runbooks automatically.")
                )
            } else {
                List {
                    ForEach(schedules) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            // Header: name + actions
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 18)
                                Text(entry.name)
                                    .font(.headline)
                                Spacer()
                                Button {
                                    if editingName == entry.id {
                                        editingName = nil
                                    } else {
                                        editingName = entry.id
                                        editSchedule = entry.schedule
                                    }
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.secondary)
                                .help("Edit schedule")
                                Button(role: .destructive) {
                                    removeSchedule(name: entry.name, schedule: entry.schedule)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.secondary)
                                .help("Remove schedule")
                            }

                            if editingName == entry.id {
                                HStack(spacing: 8) {
                                    Image(systemName: "clock")
                                        .foregroundStyle(.secondary)
                                    TextField("Cron schedule", text: $editSchedule)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(maxWidth: 200)
                                        .onSubmit { updateSchedule(name: entry.name) }
                                    Button("Save") { updateSchedule(name: entry.name) }
                                        .disabled(editSchedule.isEmpty)
                                    Button("Cancel") { editingName = nil }
                                }

                                if !editSchedule.isEmpty {
                                    Text(CronDescription.describe(editSchedule))
                                        .font(.callout)
                                        .foregroundStyle(.orange)
                                }
                            } else {
                                // Schedule info
                                HStack(alignment: .center, spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 18, height: 18)
                                    Text(entry.schedule)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundStyle(.primary)
                                    Text(entry.description)
                                        .font(.callout)
                                        .foregroundStyle(.orange)
                                        .padding(.leading, 8)
                                }

                                // Step flowchart
                                if let book = store.runbooks.first(where: { $0.name == entry.name }) {
                                    StepFlowCanvas(steps: book.steps, colorScheme: colorScheme)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .navigationTitle("Schedules")
        .toolbar {
            ToolbarItem {
                ContextualHelpButton(topic: .scheduling)
            }
        }
        .onAppear { loadCronList() }
    }

    private var addScheduleForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Row 1: Runbook name with autocomplete
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Runbook")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Name", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .focused($isNameFocused)

                    if showSuggestions {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredRunbooks.prefix(8)) { book in
                                Button {
                                    newName = book.name
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

                Button("Add") { addSchedule() }
                    .disabled(newName.isEmpty || newSchedule.isEmpty)
                    .controlSize(.large)
                    .padding(.top, 16)
            }

            // Row 2: Cron schedule with description + diagram
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Schedule")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g., 0 3 * * 0", text: $newSchedule)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                        .focused($isScheduleFocused)
                        .onChange(of: isScheduleFocused) { _, focused in
                            if !focused {
                                cronDescription = CronDescription.describe(newSchedule)
                            }
                        }
                        .onSubmit {
                            cronDescription = CronDescription.describe(newSchedule)
                        }

                    if !cronDescription.isEmpty {
                        Text(cronDescription)
                            .font(.callout)
                            .foregroundStyle(.orange)
                            .padding(.top, 2)
                    }
                }

                cronDiagram
                    .padding(.top, 2)
            }
        }
        .padding()
    }

    private var cronDiagram: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                Text("┌───────── minute (0-59)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("│ ┌─────── hour (0-23)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("│ │ ┌───── day of month (1-31)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("│ │ │ ┌─── month (1-12)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("│ │ │ │ ┌─ day of week (0-6, Sun=0)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("* * * * *")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.orange)
            }

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

    private func loadCronList() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let result = try await RunbookCLI.shared.cronList()
                await MainActor.run {
                    output = result
                    schedules = parseCronList(result)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func parseCronList(_ text: String) -> [ScheduleEntry] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard lines.count > 1 else { return [] }

        var entries: [ScheduleEntry] = []
        for line in lines.dropFirst() { // skip header
            // Format: "name  schedule  command" with variable whitespace
            // The schedule is 5 cron fields, so we need to parse carefully
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Split on 2+ spaces to get columns
            let parts = trimmed.components(separatedBy: "  ").filter { !$0.isEmpty }.map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2 else { continue }

            let name = parts[0]

            // The schedule is the 5 cron fields — find them after the name
            // Remove the name prefix, then extract 5 space-separated fields
            var remainder = trimmed
            if let nameRange = remainder.range(of: name) {
                remainder = String(remainder[nameRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            }

            let tokens = remainder.split(separator: " ").map(String.init)
            guard tokens.count >= 5 else { continue }

            let schedule = tokens[0...4].joined(separator: " ")
            let command = tokens.count > 5 ? tokens[5...].joined(separator: " ") : ""

            entries.append(ScheduleEntry(
                name: name,
                schedule: schedule,
                command: command,
                description: CronDescription.describe(schedule)
            ))
        }
        return entries
    }

    private func updateSchedule(name: String) {
        // Find the old schedule from the editing entry ID
        let oldSchedule = schedules.first { $0.id == editingName }?.schedule
        errorMessage = nil
        let newSched = editSchedule
        Task {
            do {
                if let old = oldSchedule {
                    _ = try await RunbookCLI.shared.cronRemove(name: name, schedule: old)
                }
                _ = try await RunbookCLI.shared.cronAdd(name: name, schedule: newSched)
                await MainActor.run { editingName = nil }
                loadCronList()
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    private func removeSchedule(name: String, schedule: String) {
        errorMessage = nil
        Task {
            do {
                _ = try await RunbookCLI.shared.cronRemove(name: name, schedule: schedule)
                loadCronList()
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

}


private extension CronView {
    func addSchedule() {
        errorMessage = nil
        Task {
            do {
                _ = try await RunbookCLI.shared.cronAdd(name: newName, schedule: newSchedule)
                await MainActor.run {
                    newName = ""
                    newSchedule = ""
                    showAdd = false
                }
                loadCronList()
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }
}
