import SwiftUI

/// Single-pixel horizontal dashed line, full-width. Used between
/// schedule sub-rows inside a multi-schedule group card. Drawn via
/// `Path.stroke(style:)` so the dash pattern is honored — SwiftUI's
/// built-in `Divider` is always solid, and stroking a `Rectangle`
/// shape strokes all four edges instead of just one line.
struct DashedHorizontalLine: View {
    var color: Color = Color.secondary.opacity(0.25)
    var dash: [CGFloat] = [3, 4]
    var lineWidth: CGFloat = 1

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let y = geo.size.height / 2
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: geo.size.width, y: y))
            }
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, dash: dash))
        }
        .frame(height: lineWidth + 1)
    }
}

/// Inline editor for a schedule's `--var key=value` payload. Renders one
/// FilterField pair per pair (workspace rule: never SwiftUI TextField on
/// macOS — phantom autofill popup), a trash button per row, and an "Add
/// variable" button at the bottom. Used by both the single-schedule edit
/// form (CronScheduleRow) and the per-schedule sub-row form
/// (CronScheduleSubRow); the binding to `[CronVarPair]` is owned by
/// CronView so save handlers can read it alongside `editSchedule` in one
/// shot.
struct CronVarsEditor: View {
    @Binding var pairs: [CronVarPair]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Variables")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !pairs.isEmpty {
                    Text("(--var key=value baked into the schedule)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
            }
            // ForEach by id is stable across key/value edits, so the
            // FilterFields don't lose focus on every keystroke.
            ForEach($pairs) { $pair in
                HStack(spacing: 4) {
                    FilterField(
                        placeholder: "key",
                        text: $pair.key
                    )
                    .frame(maxWidth: 140)
                    Text("=")
                        .foregroundStyle(.secondary)
                    FilterField(
                        placeholder: "value",
                        text: $pair.value
                    )
                    .frame(maxWidth: 240)
                    Button(role: .destructive) {
                        if let idx = pairs.firstIndex(where: { $0.id == pair.id }) {
                            pairs.remove(at: idx)
                        }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Remove variable")
                    Spacer(minLength: 0)
                }
            }
            Button {
                pairs.append(CronVarPair())
            } label: {
                Label("Add variable", systemImage: "plus.circle")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.accentColor)
        }
        .padding(.leading, 22)
        .padding(.top, 2)
    }
}

/// Renders one runbook with N>=2 schedules: a single runbook-level header
/// (status dot, name, last-run badge, expand chevron) followed by one
/// `CronScheduleSubRow` per schedule, then a single shared
/// `StepFlowCanvas` at the bottom.
///
/// Runbooks with exactly one schedule keep using `CronScheduleRow` —
/// `CronView` branches on `group.schedules.count`. Splitting the grouped
/// case into its own type keeps single-schedule rendering byte-identical
/// to the prior implementation, so users without the multi-schedule
/// pattern see no visual change.
struct CronRunbookGroupView: View {
    @Environment(RunbookStore.self) private var store
    @Environment(RunSessionStore.self) private var runSessions
    @Environment(\.colorScheme) private var colorScheme

    let group: CronView.RunbookGroup
    @Binding var editingName: String?
    @Binding var editSchedule: String
    /// See `CronScheduleRow.editVars` — owned by `CronView`; we just
    /// thread the binding through to the sub-rows.
    @Binding var editVars: [CronVarPair]
    /// Same single-slot hover ownership the per-schedule rows use, so the
    /// step-type legend stays scoped to whichever sub-row is hovered.
    @Binding var hoveredRowID: String?
    let onUpdate: (String) -> Void
    let onRemove: (String, String) -> Void

    @State private var now = Date()
    private let tick = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    @State private var showLogSheet = false
    /// Runbook-level expand toggle. Defaults to expanded; collapsing
    /// hides every sub-row and the step canvas, leaving the one-line
    /// header. The CronScheduleRow uses the same pattern.
    @State private var isExpanded = true

    private var lastRun: HistoryRecord? {
        store.history(for: group.name).first
    }

    private var latestLogURL: URL? {
        guard let last = lastRun else { return nil }
        return StepLogExtractor.findLogURL(for: last)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Runbook-level header. Mirrors CronScheduleRow's header so
            // single- and multi-schedule rows look the same from the top
            // line down — only the body below differs.
            HStack(spacing: 4) {
                statusDot
                    .frame(width: 18)
                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(group.name)
                        .font(.headline)
                    lastRunBadge
                        .padding(.leading, 6)
                    Text("\(group.schedules.count) schedules")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                }
                .contentShape(Rectangle())
                .onTapGesture { isExpanded.toggle() }
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                Spacer()
            }

            if isExpanded {
                // Per-schedule sub-rows. Each row carries its own clock /
                // schedule / next-run / vars / edit / delete affordances;
                // shared chrome (header, step canvas) lives at the group
                // level.
                ForEach(group.schedules) { entry in
                    // Faint dashed separator between siblings — only
                    // between rows, not before the first or after the
                    // last. Matches the single-schedule card visually
                    // (no per-row chrome, no indent) while still giving
                    // the eye a hint of where one schedule ends and the
                    // next begins.
                    if entry.id != group.schedules.first?.id {
                        DashedHorizontalLine()
                            .padding(.vertical, 4)
                    }
                    CronScheduleSubRow(
                        entry: entry,
                        editingName: $editingName,
                        editSchedule: $editSchedule,
                        editVars: $editVars,
                        hoveredRowID: $hoveredRowID,
                        now: now,
                        onUpdate: onUpdate,
                        onRemove: onRemove
                    )
                }

                // Step flowchart rendered once per runbook. The pipeline
                // depends only on the YAML, not the schedule.
                if let book = store.runbooks.first(where: { $0.name == group.name }) {
                    StepFlowCanvas(steps: book.steps, colorScheme: colorScheme, runbookName: book.name)
                        .padding(.top, 4)
                }
            }
        }
        .padding(.vertical, 4)
        .onReceive(tick) { now = $0 }
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
        }
        .sheet(isPresented: $showLogSheet) {
            if let url = latestLogURL {
                LogViewerSheet(url: url, matchDate: lastRun?.startedDate)
            }
        }
    }

    // MARK: - Subviews & helpers

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

    private func runRunbook(dryRun: Bool) {
        guard let book = store.runbooks.first(where: { $0.name == group.name }) else { return }
        // Group-level "Run now" uses YAML defaults — no schedule context
        // implies no per-schedule var bake-in. Use a sub-row's Run-now
        // (added later if needed) for per-schedule var resolution.
        let vars = (book.variables ?? []).reduce(into: [String: String]()) { acc, v in
            if let def = v.`default` { acc[v.name] = def }
        }
        runSessions.start(runbook: book, vars: vars, dryRun: dryRun)
    }

    private func openInRunbookDetail() {
        NotificationCenter.default.post(
            name: .runbookNavigateToStep,
            object: nil,
            userInfo: ["runbookName": group.name]
        )
    }
}

/// One schedule line inside a grouped runbook card: the cron expression,
/// human description, next-run, baked-in --var pairs, and per-schedule
/// edit / delete buttons. Lives only inside `CronRunbookGroupView`.
struct CronScheduleSubRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let entry: CronView.ScheduleEntry
    @Binding var editingName: String?
    @Binding var editSchedule: String
    @Binding var editVars: [CronVarPair]
    @Binding var hoveredRowID: String?
    let now: Date
    let onUpdate: (String) -> Void
    let onRemove: (String, String) -> Void

    private var nextRun: Date? {
        CronNextRun.next(for: entry.schedule, after: now)
    }

    private var hasVarChanges: Bool {
        editVars.asCronVarStrings() != entry.vars
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if editingName == entry.id {
                editForm
            } else {
                scheduleLine
                if !entry.vars.isEmpty {
                    varsLine
                }
                nextRunLine
            }
        }
        .padding(.vertical, 2)
        .onHover { inside in
            if inside { hoveredRowID = entry.id }
        }
        .contextMenu {
            Button {
                editingName = entry.id
                editSchedule = entry.schedule
                editVars = entry.vars.asCronVarPairs()
            } label: {
                Label("Edit schedule", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onRemove(entry.name, entry.schedule)
            } label: {
                Label("Remove schedule", systemImage: "trash")
            }
            Divider()
            Button {
                copyCronExpression()
            } label: {
                Label("Copy cron expression", systemImage: "doc.on.doc")
            }
        }
    }

    @ViewBuilder
    private var scheduleLine: some View {
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
            Spacer()
            Button {
                editingName = entry.id
                editSchedule = entry.schedule
                editVars = entry.vars.asCronVarPairs()
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
    }

    @ViewBuilder
    private var varsLine: some View {
        HStack(alignment: .center, spacing: 4) {
            Color.clear.frame(width: 18, height: 16)
            Image(systemName: "slider.horizontal.3")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.vars.joined(separator: "  "))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

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
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var editForm: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    FilterField(placeholder: "Cron schedule", text: $editSchedule, onCommit: {
                        if !editSchedule.isEmpty && (editSchedule != entry.schedule || hasVarChanges) {
                            onUpdate(entry.name)
                        } else {
                            editingName = nil
                        }
                    }, autoFocus: true)
                    .frame(maxWidth: 200)
                    Button("Save") { onUpdate(entry.name) }
                        .disabled(editSchedule.isEmpty || (editSchedule == entry.schedule && !hasVarChanges))
                    Button("Cancel") { editingName = nil }
                        .font(.caption)
                }

                if !editSchedule.isEmpty {
                    Text(CronDescription.describe(editSchedule))
                        .font(.callout)
                        .foregroundStyle(.orange)
                }

                CronVarsEditor(pairs: $editVars)
            }
            CronDiagramCompact()
        }
    }

    private func copyCronExpression() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.schedule, forType: .string)
    }
}
