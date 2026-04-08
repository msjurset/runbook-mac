import SwiftUI

struct RunbookDetailView: View {
    @Environment(RunbookStore.self) private var store
    let runbook: Runbook
    @State private var showEditor = false
    @State private var showRunner = false
    @State private var showCreateFromTemplate = false
    @State private var showSchedule = false
    @State private var expandedSteps: Set<Int> = []

    private var isTemplate: Bool {
        store.templates.contains(where: { $0.id == runbook.id })
    }

    var body: some View {
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
                        showRunner = true
                    }
                    .accessibilityIdentifier("toolbar.run")
                    .tint(.green)
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            EditorView(runbook: runbook)
        }
        .sheet(isPresented: $showRunner) {
            RunnerView(runbook: runbook)
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
                    configRow("command", shell.command)
                    if let dir = shell.dir {
                        configRow("dir", dir)
                    }
                }
            }

            if let ssh = step.ssh {
                configSection("SSH") {
                    configRow("host", ssh.host)
                    if let user = ssh.user {
                        configRow("user", user)
                    }
                    if let port = ssh.port {
                        configRow("port", "\(port)")
                    }
                    configRow("command", ssh.command)
                    if ssh.agent_auth == true {
                        configRow("agent_auth", "true")
                    }
                    if let keyFile = ssh.key_file {
                        configRow("key_file", keyFile)
                    }
                }
            }

            if let http = step.http {
                configSection("HTTP") {
                    if let method = http.method {
                        configRow("method", method)
                    }
                    configRow("url", http.url)
                    if let headers = http.headers, !headers.isEmpty {
                        ForEach(Array(headers.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                            configRow("header: \(key)", value)
                        }
                    }
                    if let body = http.body {
                        configRow("body", body)
                    }
                }
            }

            if let confirm = step.confirm {
                configSection("Confirm") {
                    configRow("message", confirm)
                }
            }

            // Additional config
            if step.timeout != nil || step.on_error != nil || step.retries != nil ||
                step.capture != nil || step.condition != nil {
                configSection("Options") {
                    if let timeout = step.timeout {
                        configRow("timeout", timeout)
                    }
                    if let onErr = step.on_error {
                        configRow("on_error", onErr)
                    }
                    if let retries = step.retries {
                        configRow("retries", "\(retries)")
                    }
                    if let capture = step.capture {
                        configRow("capture → ", capture)
                    }
                    if let condition = step.condition {
                        configRow("condition", condition)
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

    private func configRow(_ label: String, _ value: String) -> some View {
        EditableConfigRow(label: label, value: value, runbook: runbook, store: store)
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
