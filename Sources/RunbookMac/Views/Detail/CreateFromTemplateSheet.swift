import SwiftUI

struct CreateFromTemplateSheet: View {
    @Environment(RunbookStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let template: Runbook
    var isDuplicate = false
    @State private var name = ""
    @State private var errorMessage: String?

    private var isTemplate: Bool {
        !isDuplicate
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(isDuplicate ? "Duplicate Runbook" : "New Runbook from Template")
                .font(.headline)

            HStack(spacing: 8) {
                Text(isDuplicate ? "Source:" : "Template:")
                    .foregroundStyle(.secondary)
                Label(template.name, systemImage: isDuplicate ? "doc.text" : "doc.on.doc")
                    .foregroundStyle(isDuplicate ? Color.primary : Color.orange)
            }
            .font(.callout)

            TextField("Runbook name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit { create() }

            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") { create() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func create() {
        errorMessage = nil
        let filename = "\(name).yaml"

        // Check for existing runbook with same name
        if store.runbooks.contains(where: { $0.name == name }) {
            errorMessage = "A runbook named \"\(name)\" already exists."
            return
        }

        // Read template YAML and replace the name
        guard var yaml = store.readRawYAML(for: template) else {
            errorMessage = "Could not read template file."
            return
        }
        yaml = replaceName(in: yaml, with: name)

        do {
            try store.saveRaw(yaml, to: filename)
            store.loadAll()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func replaceName(in yaml: String, with newName: String) -> String {
        let lines = yaml.components(separatedBy: "\n")
        var result: [String] = []
        var replaced = false
        for line in lines {
            if !replaced && line.trimmingCharacters(in: .whitespaces).hasPrefix("name:") {
                let indent = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
                result.append("\(indent)name: \(newName)")
                replaced = true
            } else {
                result.append(line)
            }
        }
        return result.joined(separator: "\n")
    }
}
