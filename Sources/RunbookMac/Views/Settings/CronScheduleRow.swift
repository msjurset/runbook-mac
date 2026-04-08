import SwiftUI

struct CronScheduleRow: View {
    @Environment(RunbookStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    let entry: CronView.ScheduleEntry
    @Binding var editingName: String?
    @Binding var editSchedule: String
    let onUpdate: (String) -> Void
    let onRemove: (String, String) -> Void

    var body: some View {
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
                    onRemove(entry.name, entry.schedule)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Remove schedule")
            }

            if editingName == entry.id {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .foregroundStyle(.secondary)
                            FilterField(placeholder: "Cron schedule", text: $editSchedule, onCommit: {
                                if !editSchedule.isEmpty && editSchedule != entry.schedule {
                                    onUpdate(entry.name)
                                } else {
                                    editingName = nil
                                }
                            }, autoFocus: true)
                            .frame(maxWidth: 200)
                            Button("Save") { onUpdate(entry.name) }
                                .disabled(editSchedule.isEmpty || editSchedule == entry.schedule)
                            Button("Cancel") { editingName = nil }
                                .font(.caption)
                        }

                        if !editSchedule.isEmpty {
                            Text(CronDescription.describe(editSchedule))
                                .font(.callout)
                                .foregroundStyle(.orange)
                        }
                    }

                    CronDiagramCompact()
                }

                // Step flowchart (visible during edit too)
                if let book = store.runbooks.first(where: { $0.name == entry.name }) {
                    StepFlowCanvas(steps: book.steps, colorScheme: colorScheme)
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
