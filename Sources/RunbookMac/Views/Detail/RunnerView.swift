import SwiftUI

struct RunnerView: View {
    let runbook: Runbook
    @Environment(\.dismiss) private var dismiss
    @State private var output: [String] = []
    @State private var isRunning = false
    @State private var success: Bool?
    @State private var vars: [String: String] = [:]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Run: \(runbook.name)")
                        .font(.headline)
                    if let desc = runbook.description {
                        Text(desc).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                statusBadge
            }
            .padding()

            Divider()

            // Variable inputs
            if let defs = runbook.variables, !defs.isEmpty {
                variableInputs(defs)
                Divider()
            }

            // Output
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(output.enumerated()), id: \.offset) { idx, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .id(idx)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: output.count) {
                    if let last = output.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
            .background(.black.opacity(0.03))

            Divider()

            // Controls
            HStack {
                if isDone {
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                    Spacer()
                    Button("Run Again") {
                        success = nil
                        startRun()
                    }
                } else if isRunning {
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 4)
                    Text("Running...")
                        .foregroundStyle(.secondary)
                } else {
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Run") { startRun() }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            // Pre-fill variable defaults
            for v in runbook.variables ?? [] {
                if let def = v.default, !def.hasPrefix("op://") {
                    vars[v.name] = def
                }
            }
        }
    }

    private var isDone: Bool { success != nil && !isRunning }

    private func variableInputs(_ defs: [VariableDef]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Variables")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(defs) { v in
                HStack {
                    Text(v.name)
                        .font(.body.monospaced())
                        .frame(width: 120, alignment: .trailing)
                    if isDone {
                        Text(vars[v.name] ?? v.default ?? "")
                            .font(.body.monospaced())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        TextField(v.default ?? "", text: binding(for: v.name))
                            .textFieldStyle(.roundedBorder)
                            .disabled(isRunning)
                        if v.required == true {
                            Text("required")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { vars[key] ?? "" },
            set: { vars[key] = $0 }
        )
    }

    @ViewBuilder
    private var statusBadge: some View {
        if let success {
            Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(success ? .green : .red)
                .font(.title2)
        }
    }

    private func startRun() {
        output = []
        success = nil
        isRunning = true

        Task {
            do {
                let result = try await RunbookCLI.shared.run(
                    name: runbook.name,
                    vars: vars
                ) { line in
                    Task { @MainActor in
                        output.append(line)
                    }
                }
                await MainActor.run {
                    success = result
                    isRunning = false
                }
            } catch {
                await MainActor.run {
                    output.append("Error: \(error.localizedDescription)")
                    success = false
                    isRunning = false
                }
            }
        }
    }
}
