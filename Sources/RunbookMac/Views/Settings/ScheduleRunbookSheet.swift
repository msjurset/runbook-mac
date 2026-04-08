import SwiftUI

struct ScheduleRunbookSheet: View {
    let runbookName: String
    @Environment(\.dismiss) private var dismiss
    @State private var schedule = ""
    @State private var existingSchedule: String?
    @State private var cronDescription = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(.blue)
                Text(existingSchedule != nil ? "Edit Schedule" : "Schedule Runbook")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 8) {
                Text("Runbook:")
                    .foregroundStyle(.secondary)
                Text(runbookName)
                    .fontWeight(.medium)
            }

            if isLoading {
                ProgressView()
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cron Schedule")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    FilterField(placeholder: "e.g., 0 9 * * *", text: $schedule)
                        .frame(maxWidth: 250)

                    if !cronDescription.isEmpty {
                        Text(cronDescription)
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }

                    CronDiagram()
                        .padding(.top, 4)
                }
                .onChange(of: schedule) {
                    cronDescription = CronDescription.describe(schedule)
                }
            }

            if let err = errorMessage {
                Label(err, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                if existingSchedule != nil {
                    Button("Remove Schedule", role: .destructive) {
                        removeSchedule()
                    }
                    .disabled(isSaving)
                }

                Spacer()

                Button(existingSchedule != nil ? "Update" : "Schedule") {
                    saveSchedule()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(schedule.isEmpty || isSaving || schedule == existingSchedule)
            }
        }
        .padding()
        .frame(width: 450)
        .onAppear { loadExisting() }
    }

    private func loadExisting() {
        Task {
            do {
                let result = try await RunbookCLI.shared.cronList()
                await MainActor.run {
                    let lines = result.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
                    for line in lines.dropFirst() {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        let parts = trimmed.components(separatedBy: "  ").filter { !$0.isEmpty }.map { $0.trimmingCharacters(in: .whitespaces) }
                        guard parts.count >= 2, parts[0] == runbookName else { continue }

                        var remainder = trimmed
                        if let range = remainder.range(of: parts[0]) {
                            remainder = String(remainder[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                        }
                        let tokens = remainder.split(separator: " ").map(String.init)
                        if tokens.count >= 5 {
                            existingSchedule = tokens[0...4].joined(separator: " ")
                            schedule = existingSchedule!
                            cronDescription = CronDescription.describe(schedule)
                        }
                        break
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }

    private func saveSchedule() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                // Remove old schedule if editing
                if let old = existingSchedule {
                    _ = try await RunbookCLI.shared.cronRemove(name: runbookName, schedule: old)
                }
                _ = try await RunbookCLI.shared.cronAdd(name: runbookName, schedule: schedule)
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }

    private func removeSchedule() {
        guard let old = existingSchedule else { return }
        isSaving = true
        errorMessage = nil
        Task {
            do {
                _ = try await RunbookCLI.shared.cronRemove(name: runbookName, schedule: old)
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}
