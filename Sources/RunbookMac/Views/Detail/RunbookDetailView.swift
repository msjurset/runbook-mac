import SwiftUI

struct RunbookDetailView: View {
    @Environment(RunbookStore.self) private var store
    let runbook: Runbook
    @State private var showEditor = false
    @State private var showRunner = false

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
        }
        .navigationTitle(runbook.name)
        .toolbar {
            ToolbarItemGroup {
                Button("Edit", systemImage: "pencil") {
                    showEditor = true
                }
                Button("Run", systemImage: "play.fill") {
                    showRunner = true
                }
                .tint(.green)
            }
        }
        .sheet(isPresented: $showEditor) {
            EditorView(runbook: runbook)
        }
        .sheet(isPresented: $showRunner) {
            RunnerView(runbook: runbook)
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

    private var stepsSection: some View {
        GroupBox("Steps") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(runbook.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top) {
                        Text("\(index + 1)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.tertiary)
                            .frame(width: 24, alignment: .trailing)
                        stepTypeIcon(step)
                        VStack(alignment: .leading) {
                            Text(step.name).fontWeight(.medium)
                            stepDetail(step)
                        }
                    }
                    if index < runbook.steps.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

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

    private func stepDetail(_ step: Step) -> some View {
        HStack(spacing: 8) {
            if let t = step.type {
                Text(t).font(.caption).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.quaternary).clipShape(Capsule())
            }
            if let timeout = step.timeout {
                Text("timeout: \(timeout)").font(.caption).foregroundStyle(.secondary)
            }
            if let onErr = step.on_error {
                Text("on_error: \(onErr)").font(.caption).foregroundStyle(.secondary)
            }
            if step.capture != nil {
                Image(systemName: "arrow.right.circle").font(.caption).foregroundStyle(.secondary)
            }
            if step.condition != nil {
                Image(systemName: "questionmark.diamond").font(.caption).foregroundStyle(.secondary)
            }
        }
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
                                Text(rec.started_at)
                                    .font(.caption.monospaced())
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
