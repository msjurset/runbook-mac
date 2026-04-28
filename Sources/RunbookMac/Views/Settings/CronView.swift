import SwiftUI

struct CronView: View {
    struct ScheduleEntry: Identifiable {
        var id: String { "\(name)|\(schedule)" }
        var name: String
        var schedule: String
        var command: String
        var description: String
    }

    @State private var schedules: [ScheduleEntry] = []
    @State private var isLoading = false
    @State private var showAdd = false
    @State private var newName = ""
    @State private var newSchedule = ""
    @State private var errorMessage: String?
    @State private var cronDescription = ""
    @State private var editingName: String?
    @State private var editSchedule = ""

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
                CronAddForm(
                    name: $newName,
                    schedule: $newSchedule,
                    cronDescription: $cronDescription,
                    onAdd: addSchedule
                )
                Divider()
            }

            if let err = errorMessage {
                ErrorBanner(message: err) { errorMessage = nil }
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
                        CronScheduleRow(
                            entry: entry,
                            editingName: $editingName,
                            editSchedule: $editSchedule,
                            onUpdate: updateSchedule,
                            onRemove: removeSchedule
                        )
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

    // MARK: - Data

    private func loadCronList() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let result = try await RunbookCLI.shared.cronList()
                await MainActor.run {
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
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.components(separatedBy: "  ").filter { !$0.isEmpty }.map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2 else { continue }

            let name = parts[0]
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
        // Sort by next fire time so the most-imminent job is on top.
        // Schedules whose expression can't be parsed sort to the bottom.
        return entries.sorted { lhs, rhs in
            let lNext = CronNextRun.next(for: lhs.schedule) ?? .distantFuture
            let rNext = CronNextRun.next(for: rhs.schedule) ?? .distantFuture
            return lNext < rNext
        }
    }

    private func addSchedule() {
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

    private func updateSchedule(name: String) {
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
