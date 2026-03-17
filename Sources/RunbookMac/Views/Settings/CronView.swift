import SwiftUI

struct CronView: View {
    @State private var output = ""
    @State private var isLoading = false
    @State private var showAdd = false
    @State private var newName = ""
    @State private var newSchedule = ""
    @State private var errorMessage: String?

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

            if output.isEmpty && !isLoading {
                ContentUnavailableView(
                    "No Schedules",
                    systemImage: "calendar.badge.clock",
                    description: Text("Add a cron schedule to run runbooks automatically.")
                )
            } else {
                ScrollView {
                    Text(output)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Runbook name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                TextField("Cron schedule (e.g., 0 3 * * 0)", text: $newSchedule)
                    .textFieldStyle(.roundedBorder)
                Button("Add") { addSchedule() }
                    .disabled(newName.isEmpty || newSchedule.isEmpty)
            }
            Text("Format: minute hour day-of-month month day-of-week")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func loadCronList() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let result = try await RunbookCLI.shared.cronList()
                await MainActor.run {
                    output = result
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
}
