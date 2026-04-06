import SwiftUI

struct RunnerView: View {
    let runbook: Runbook
    @State var dryRun = false
    @Environment(\.dismiss) private var dismiss
    @State private var output: [String] = []
    @State private var isRunning = false
    @State private var success: Bool?
    @State private var vars: [String: String] = [:]
    @State private var runTask: Task<Void, Never>?
    @State private var runStartedAt: Date?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    HStack(spacing: 8) {
                        Text("\(dryRun ? "Dry Run" : "Run"): \(runbook.name)")
                            .font(.headline)
                        if dryRun {
                            Text("preview")
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
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
                VariableInputsView(
                    variables: defs,
                    vars: $vars,
                    isEditable: !isRunning && !isDone
                )
                Divider()
            }

            // Output
            RunnerOutputView(runbookName: runbook.name, runStartedAt: runStartedAt, output: $output)

            Divider()

            // Controls
            HStack {
                if isDone {
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                    Spacer()
                    Toggle("Dry Run", isOn: $dryRun)
                        .toggleStyle(.checkbox)
                    Button(dryRun ? "Run Again" : "Run") {
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
                    Button("Stop", role: .destructive) { stopRun() }
                        .keyboardShortcut(".", modifiers: .command)
                } else {
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Toggle("Dry Run", isOn: $dryRun)
                        .toggleStyle(.checkbox)
                    Button("Run") { startRun() }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            for v in runbook.variables ?? [] {
                if let def = v.default, !def.hasPrefix("op://") {
                    vars[v.name] = def
                }
            }
        }
    }

    private var isDone: Bool { success != nil && !isRunning }

    @ViewBuilder
    private var statusBadge: some View {
        if let success {
            Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(success ? .green : .red)
                .font(.title2)
        }
    }

    // MARK: - Execution

    private func startRun() {
        output = []
        success = nil
        isRunning = true
        runStartedAt = Date()

        runTask = Task {
            do {
                let result = try await RunbookCLI.shared.run(
                    name: runbook.name,
                    vars: vars,
                    dryRun: dryRun
                ) { line in
                    Task { @MainActor in
                        output.append(line)
                    }
                }
                await MainActor.run {
                    success = result
                    isRunning = false
                }
            } catch is CancellationError {
                await MainActor.run {
                    output.append("Stopped.")
                    success = false
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

    private func stopRun() {
        runTask?.cancel()
    }
}
