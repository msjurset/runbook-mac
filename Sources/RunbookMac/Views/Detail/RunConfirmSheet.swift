import SwiftUI

/// Small pre-run dialog that collects variable inputs for a runbook and then
/// dispatches the run into the RunSessionStore. Shown only when the runbook
/// declares variables; otherwise the Run toolbar button kicks off
/// immediately.
struct RunConfirmSheet: View {
    let runbook: Runbook
    /// Seed the Dry Run checkbox — matches the toolbar toggle or the
    /// session being retried.
    var initialDryRun: Bool = false
    /// Seed variable values — use the session's vars when retrying.
    var initialVars: [String: String] = [:]
    let onRun: (_ vars: [String: String], _ dryRun: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var vars: [String: String] = [:]
    @State private var dryRun = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Run: \(runbook.name)")
                        .font(.headline)
                    if let desc = runbook.description {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
            }
            .padding()

            Divider()

            if let defs = runbook.variables, !defs.isEmpty {
                VariableInputsView(variables: defs, vars: $vars, isEditable: true)
                Divider()
            }

            HStack {
                Toggle("Dry Run", isOn: $dryRun)
                    .toggleStyle(.checkbox)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(dryRun ? "Dry Run" : "Run") {
                    onRun(vars, dryRun)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 480, minHeight: 260)
        .onAppear {
            // Seed from initialVars (when retrying) or from the runbook's
            // declared defaults (first launch).
            if !initialVars.isEmpty {
                vars = initialVars
            } else {
                for v in runbook.variables ?? [] {
                    if let def = v.default, !def.hasPrefix("op://") {
                        vars[v.name] = def
                    }
                }
            }
            dryRun = initialDryRun
        }
    }
}
