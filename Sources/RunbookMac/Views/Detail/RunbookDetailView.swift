import SwiftUI

struct RunbookDetailView: View {
    @Environment(RunbookStore.self) private var store
    @Environment(RunSessionStore.self) private var runSessions
    /// Initial runbook passed from the sidebar selection. Used only as a
    /// fallback and to hold the lookup id; live reads go through `runbook`.
    private let initialRunbook: Runbook
    @State private var showEditor = false
    @State private var showRunConfirm = false
    @State private var showCreateFromTemplate = false
    @State private var showSchedule = false
    @State private var expandedSteps: Set<Int> = []

    init(runbook: Runbook) {
        self.initialRunbook = runbook
    }

    /// Resolve the latest Runbook instance from the store by name so that
    /// edits saved to disk (which trigger `store.loadAll()`) refresh this
    /// view automatically. Without this indirection, the `let runbook` copy
    /// from the sidebar selection went stale after inline edits.
    private var runbook: Runbook {
        store.runbooks.first(where: { $0.name == initialRunbook.name })
            ?? store.templates.first(where: { $0.name == initialRunbook.name })
            ?? initialRunbook
    }

    private var isTemplate: Bool {
        store.templates.contains(where: { $0.id == runbook.id })
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if let vars = runbook.variables, !vars.isEmpty {
                        variablesSection(vars)
                    }
                    stepsSection
                    if let notify = runbook.notify {
                        notifySection(notify)
                    }
                    historyPreview
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onReceive(NotificationCenter.default.publisher(for: .runbookExpandStep)) { note in
                guard let info = note.userInfo,
                      let name = info["runbookName"] as? String,
                      name == runbook.name,
                      let stepName = info["stepName"] as? String,
                      let idx = runbook.steps.firstIndex(where: { $0.name == stepName }) else { return }
                expandedSteps.insert(idx)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation { proxy.scrollTo("step-\(idx)", anchor: .top) }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ContextualHelpButton(topic: .runbookFormat)
                Button("Edit", systemImage: "pencil") {
                    showEditor = true
                }
                .accessibilityIdentifier("toolbar.edit")
                if isTemplate {
                    Button("New from Template", systemImage: "plus.doc.on.doc") {
                        showCreateFromTemplate = true
                    }
                    .accessibilityIdentifier("toolbar.createFromTemplate")
                    .tint(.orange)
                } else {
                    Button("Schedule", systemImage: "calendar.badge.clock") {
                        showSchedule = true
                    }
                    .accessibilityIdentifier("toolbar.schedule")
                    .help("Schedule run")
                    Button("Run", systemImage: "play.fill") {
                        showRunConfirm = true
                    }
                    .accessibilityIdentifier("toolbar.run")
                    .tint(.green)
                    .help("Run this runbook")
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            EditorView(runbook: runbook)
        }
        .sheet(isPresented: $showRunConfirm) {
            RunConfirmSheet(runbook: runbook) { vars, dryRun in
                _ = runSessions.start(runbook: runbook, vars: vars, dryRun: dryRun)
            }
        }
        .sheet(isPresented: $showSchedule) {
            ScheduleRunbookSheet(runbookName: runbook.name)
        }
        .sheet(isPresented: $showCreateFromTemplate) {
            CreateFromTemplateSheet(template: runbook)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let desc = runbook.description, !desc.isEmpty {
                Text(desc)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Label("\(runbook.steps.count) steps", systemImage: "list.number")
                if let vars = runbook.variables {
                    Label("\(vars.count) variables", systemImage: "textformat.abc")
                }
                if runbook.notify != nil {
                    Label("Notifications", systemImage: "bell")
                }
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
    }

    private func variablesSection(_ vars: [VariableDef]) -> some View {
        GroupBox("Variables") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Name").fontWeight(.semibold)
                    Text("Default").fontWeight(.semibold)
                    Text("Required").fontWeight(.semibold)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                ForEach(vars) { v in
                    GridRow {
                        Text(v.name).font(.body.monospaced())
                        Text(v.default ?? "—").font(.body.monospaced()).foregroundStyle(.secondary)
                        Text(v.required == true ? "Yes" : "No").foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Steps

    private var stepsSection: some View {
        GroupBox("Steps") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(runbook.steps.enumerated()), id: \.offset) { index, step in
                    VStack(alignment: .leading, spacing: 0) {
                        // Collapsed row — always visible
                        stepRow(index: index, step: step)
                            .contentShape(Rectangle())
                            .onTapGesture { toggleStep(index) }
                            .id("step-\(index)")

                        // Expanded config — shown on click
                        if expandedSteps.contains(index) {
                            stepConfigView(step)
                                .padding(.leading, 48)
                                .padding(.trailing, 8)
                                .padding(.bottom, 8)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if index < runbook.steps.count - 1 {
                            Divider().padding(.leading, 48)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func toggleStep(_ index: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedSteps.contains(index) {
                expandedSteps.remove(index)
            } else {
                expandedSteps.insert(index)
            }
        }
    }

    private func stepRow(index: Int, step: Step) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text("\(index + 1)")
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .frame(width: 24, alignment: .trailing)

            stepTypeIcon(step)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.name).fontWeight(.medium)
                stepBadges(step)
            }

            Spacer()

            Image(systemName: expandedSteps.contains(index) ? "chevron.up" : "chevron.down")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(expandedSteps.contains(index) ? Color.accentColor.opacity(0.05) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func stepBadges(_ step: Step) -> some View {
        HStack(spacing: 6) {
            if let t = step.type {
                badge(t)
            }
            if step.confirm != nil && step.type == nil {
                badge("confirm")
            }
            if let timeout = step.timeout {
                badge("⏱ \(timeout)")
            }
            if let onErr = step.on_error, onErr != "abort" {
                badge("on_error: \(onErr)")
            }
            if step.capture != nil {
                badge("↳ capture")
            }
            if step.condition != nil {
                badge("conditional")
            }
            if step.parallel == true {
                badge("parallel")
            }
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary)
            .clipShape(Capsule())
    }

    // MARK: - Expanded Step Config

    @ViewBuilder
    private func stepConfigView(_ step: Step) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let shell = step.shell {
                configSection("Shell") {
                    configRow("command", shell.command, stepName: step.name)
                    if let dir = shell.dir {
                        configRow("dir", dir, stepName: step.name)
                    }
                }
            }

            if let ssh = step.ssh {
                configSection("SSH") {
                    configRow("host", ssh.host, stepName: step.name)
                    if let user = ssh.user {
                        configRow("user", user, stepName: step.name)
                    }
                    if let port = ssh.port {
                        configRow("port", "\(port)", stepName: step.name)
                    }
                    configRow("command", ssh.command, stepName: step.name)
                    if ssh.agent_auth == true {
                        configRow("agent_auth", "true", stepName: step.name)
                    }
                    if let keyFile = ssh.key_file {
                        configRow("key_file", keyFile, stepName: step.name)
                    }
                }
            }

            if let http = step.http {
                configSection("HTTP") {
                    if let method = http.method {
                        configRow("method", method, stepName: step.name)
                    }
                    configRow("url", http.url, stepName: step.name)
                    if let headers = http.headers, !headers.isEmpty {
                        ForEach(Array(headers.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                            configRow("header: \(key)", value, stepName: step.name)
                        }
                    }
                    if let body = http.body {
                        configRow("body", body, stepName: step.name)
                    }
                }
            }

            if let confirm = step.confirm {
                configSection("Confirm") {
                    configRow("message", confirm, stepName: step.name)
                }
            }

            // Additional config
            if step.timeout != nil || step.on_error != nil || step.retries != nil ||
                step.capture != nil || step.condition != nil {
                configSection("Options") {
                    if let timeout = step.timeout {
                        configRow("timeout", timeout, stepName: step.name)
                    }
                    if let onErr = step.on_error {
                        configRow("on_error", onErr, stepName: step.name)
                    }
                    if let retries = step.retries {
                        configRow("retries", "\(retries)", stepName: step.name)
                    }
                    if let capture = step.capture {
                        configRow("capture → ", capture, stepName: step.name)
                    }
                    if let condition = step.condition {
                        configRow("condition", condition, stepName: step.name)
                    }
                }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func configSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            content()
        }
    }

    /// Route the Run toolbar tap: if the runbook has variables, open a small
    /// pre-run sheet to collect them; otherwise fire immediately into the
    /// RunSessionStore. Running is non-modal — the tray docks at the bottom
    /// so the user can keep browsing other runbooks while this executes.

    private func configRow(_ label: String, _ value: String, stepName: String? = nil) -> some View {
        EditableConfigRow(label: label, value: value, runbook: runbook, store: store, stepName: stepName)
    }

    // MARK: - Helpers

    private func stepTypeIcon(_ step: Step) -> some View {
        let (icon, color): (String, Color) = switch step.type {
        case "shell": ("terminal", .blue)
        case "ssh": ("network", .orange)
        case "http": ("globe", .green)
        default: ("questionmark.circle", .gray)
        }
        return Image(systemName: icon)
            .foregroundStyle(color)
            .frame(width: 20)
    }

    private func notifySection(_ notify: NotifyConfig) -> some View {
        GroupBox("Notifications") {
            HStack(spacing: 16) {
                if notify.desktop == true {
                    Label("Desktop", systemImage: "bell")
                }
                if notify.slack != nil {
                    Label("Slack", systemImage: "bubble.left")
                }
                if notify.email != nil {
                    Label("Email", systemImage: "envelope")
                }
                Spacer()
                Text("on: \(notify.on ?? "always")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var historyPreview: some View {
        let records = store.history(for: runbook.name).prefix(5)
        return Group {
            if !records.isEmpty {
                GroupBox("Recent Runs") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(records)) { rec in
                            HStack {
                                Image(systemName: rec.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(rec.success ? .green : .red)
                                Text(rec.formattedDate)
                                    .font(.caption)
                                Spacer()
                                Text(rec.duration)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
