import SwiftUI

struct CronScheduleRow: View {
    @Environment(RunbookStore.self) private var store
    @Environment(RunSessionStore.self) private var runSessions
    @Environment(\.colorScheme) private var colorScheme
    let entry: CronView.ScheduleEntry
    @Binding var editingName: String?
    @Binding var editSchedule: String
    /// Shared at the parent (CronView) so only one row's legend is visible at a
    /// time — entering this row's content area sets it to entry.id; leaving
    /// clears it. The legend renders only when this row owns the value.
    @Binding var hoveredRowID: String?
    let onUpdate: (String) -> Void
    let onRemove: (String, String) -> Void

    /// Minute-resolution clock used to keep "in 3h 12m" etc. fresh without
    /// work on every render.
    @State private var now = Date()
    private let tick = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    @State private var showLogSheet = false
    /// Per-row collapse toggle. Default expanded preserves the existing layout
    /// on first launch; clicking the runbook name collapses to just the
    /// header line.
    @State private var isExpanded = true

    private var lastRun: HistoryRecord? {
        store.history(for: entry.name).first
    }

    private var nextRun: Date? {
        CronNextRun.next(for: entry.schedule, after: now)
    }

    private var latestLogURL: URL? {
        guard let last = lastRun else { return nil }
        return StepLogExtractor.findLogURL(for: last)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: name + status + actions. Clicking the name area toggles
            // the row's expand/collapse state.
            HStack(spacing: 4) {
                statusDot
                    .frame(width: 18)
                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(entry.name)
                        .font(.headline)
                    lastRunBadge
                        .padding(.leading, 6)
                }
                .contentShape(Rectangle())
                .onTapGesture { isExpanded.toggle() }
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                Spacer()
                Button {
                    if editingName == entry.id {
                        editingName = nil
                    } else {
                        editingName = entry.id
                        editSchedule = entry.schedule
                        // Editing forces the body open so the form is visible.
                        isExpanded = true
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

            if isExpanded {
                expandedBody
            }
        }
        .padding(.vertical, 4)
        .onReceive(tick) { now = $0 }
        .onHover { inside in
            // Take legend ownership on enter only. Leaving the row WITHOUT
            // entering another keeps this row's legend visible — sticky until
            // a sibling row claims ownership. The parent's single-slot
            // hoveredRowID is what enforces "only one legend at a time."
            if inside {
                hoveredRowID = entry.id
            }
        }
        // Right-click context menu fires on any row content area that isn't
        // a pill. Pills have their own RightClickCatcher (NSView hitTest
        // returning self for .rightMouseDown) which consumes the event before
        // it can reach SwiftUI's .contextMenu, preserving the existing
        // last-run-log flyout on right-click of a pill.
        .contextMenu {
            Button {
                runRunbook(dryRun: false)
            } label: {
                Label("Run now", systemImage: "play.fill")
            }
            Button {
                runRunbook(dryRun: true)
            } label: {
                Label("Dry run now", systemImage: "play")
            }
            Divider()
            Button {
                openInRunbookDetail()
            } label: {
                Label("Open runbook", systemImage: "arrow.up.forward")
            }
            Button {
                showLogSheet = true
            } label: {
                Label("View latest log", systemImage: "doc.text.magnifyingglass")
            }
            .disabled(latestLogURL == nil)
            Button {
                copyCronExpression()
            } label: {
                Label("Copy cron expression", systemImage: "doc.on.doc")
            }
            Divider()
            Button {
                startEditing()
            } label: {
                Label("Edit schedule", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onRemove(entry.name, entry.schedule)
            } label: {
                Label("Remove schedule", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showLogSheet) {
            if let url = latestLogURL {
                LogViewerSheet(url: url, matchDate: lastRun?.startedDate)
            }
        }
    }

    /// Body shown when isExpanded is true. Extracted so the toggle is a
    /// single `if isExpanded { expandedBody }` in the main body.
    @ViewBuilder
    private var expandedBody: some View {
        Group {
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
    }

    // MARK: - Context menu actions

    private func runRunbook(dryRun: Bool) {
        guard let book = store.runbooks.first(where: { $0.name == entry.name }) else { return }
        // Use YAML defaults — same value source as cron-launched runs, since
        // there's no TTY to prompt for required-but-undefaulted vars in
        // either path. The CLI handles op:// resolution itself.
        let vars = (book.variables ?? []).reduce(into: [String: String]()) { acc, v in
            if let def = v.`default` { acc[v.name] = def }
        }
        runSessions.start(runbook: book, vars: vars, dryRun: dryRun)
    }

    private func openInRunbookDetail() {
        NotificationCenter.default.post(
            name: .runbookNavigateToStep,
            object: nil,
            userInfo: ["runbookName": entry.name]
        )
    }

    private func copyCronExpression() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.schedule, forType: .string)
    }

    private func startEditing() {
        editingName = entry.id
        editSchedule = entry.schedule
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

    /// Line beneath the schedule: "Next run: Sunday at 8:00 AM (in 3d 2h)" —
    /// also hosts the step-type legend, offset ~2 inches from the line start
    /// and shown only while this row is the hovered one (`hoveredRowID ==
    /// entry.id`). Single-row visibility is enforced by the parent storing a
    /// single id rather than per-row bools.
    @ViewBuilder
    private var nextRunLine: some View {
        HStack(alignment: .center, spacing: 6) {
            if let next = nextRun {
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
            } else {
                Image(systemName: "questionmark.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                Text("Next: unknown (couldn't parse schedule)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            // ~2-inch fixed gap, then the legend if this row is hovered.
            // Spacer at the trailing edge soaks up extra width on wide windows.
            Color.clear.frame(width: 144, height: 1)
            if hoveredRowID == entry.id {
                StepFlowLegend()
                    // Asymmetric: snappy fade-in on enter, gentle fade-out on
                    // dismiss so a passing mouse-out doesn't yank the legend
                    // away abruptly.
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeIn(duration: 0.15)),
                        removal: .opacity.animation(.easeOut(duration: 1.5))
                    ))
            }
            Spacer(minLength: 0)
        }
        // Outer animation provides the "this state change is animated" trigger
        // that lets the asymmetric transition fire; the transition's own
        // animations carry the actual timing.
        .animation(.default, value: hoveredRowID == entry.id)
    }
}
