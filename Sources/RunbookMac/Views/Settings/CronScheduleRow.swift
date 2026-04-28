import SwiftUI

struct CronScheduleRow: View {
    @Environment(RunbookStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    let entry: CronView.ScheduleEntry
    @Binding var editingName: String?
    @Binding var editSchedule: String
    let onUpdate: (String) -> Void
    let onRemove: (String, String) -> Void

    /// Minute-resolution clock used to keep "in 3h 12m" etc. fresh without
    /// work on every render.
    @State private var now = Date()
    private let tick = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var lastRun: HistoryRecord? {
        store.history(for: entry.name).first
    }

    private var nextRun: Date? {
        CronNextRun.next(for: entry.schedule, after: now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: name + status + actions
            HStack(spacing: 4) {
                statusDot
                    .frame(width: 18)
                Text(entry.name)
                    .font(.headline)
                lastRunBadge
                    .padding(.leading, 6)
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
                    StepFlowCanvas(steps: book.steps, colorScheme: colorScheme, runbookName: book.name)
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

                nextRunLine

                // Step flowchart
                if let book = store.runbooks.first(where: { $0.name == entry.name }) {
                    StepFlowCanvas(steps: book.steps, colorScheme: colorScheme, runbookName: book.name)
                }
            }
        }
        .padding(.vertical, 4)
        .onReceive(tick) { now = $0 }
    }

    // MARK: - Subviews

    /// A small colored dot whose color reflects the last run's status.
    /// gray = never run, green = success, red = failure.
    private var statusDot: some View {
        let color: Color = {
            guard let last = lastRun else { return .secondary }
            return last.success ? .green : .red
        }()
        return Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .help({
                guard let last = lastRun else { return "Never run" }
                let ok = last.success ? "Succeeded" : "Failed"
                let when = last.startedDate.map { CronRelativeTime.friendly($0) } ?? last.started_at
                return "\(ok) — \(when)"
            }())
    }

    /// Inline badge beside the runbook name: "✓ 5h ago" / "✗ 2d ago" / "Never run".
    @ViewBuilder
    private var lastRunBadge: some View {
        if let last = lastRun, let date = last.startedDate {
            HStack(spacing: 3) {
                Image(systemName: last.success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .foregroundStyle(last.success ? .green : .red)
                    .font(.caption2)
                Text("\(CronRelativeTime.until(now, from: date)) ago")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("Never run")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Line beneath the schedule: "Next run: Sunday at 8:00 AM (in 3d 2h)".
    @ViewBuilder
    private var nextRunLine: some View {
        if let next = nextRun {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "arrow.right.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                Text("Next: \(CronRelativeTime.friendly(next, from: now))")
                    .font(.callout)
                    .foregroundStyle(.primary)
                Text("in \(CronRelativeTime.until(next, from: now))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
        } else {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "questionmark.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                Text("Next: unknown (couldn't parse schedule)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
