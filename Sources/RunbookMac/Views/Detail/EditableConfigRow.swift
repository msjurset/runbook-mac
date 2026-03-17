import SwiftUI

struct EditableConfigRow: View {
    let label: String
    let value: String
    let runbook: Runbook
    let store: RunbookStore

    @State private var isEditing = false
    @State private var editValue: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 70, alignment: .trailing)

            if isEditing {
                TextField("", text: $editValue)
                    .font(.system(.caption, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .onSubmit { save() }
                    .onChange(of: isFocused) {
                        if !isFocused { save() }
                    }
                    .onExitCommand { cancel() }
            } else {
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .padding(.vertical, 1)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { startEditing() }
                    .onHover { hovering in
                        if hovering {
                            NSCursor.iBeam.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
            }
        }
    }

    private func startEditing() {
        editValue = value
        isEditing = true
        // Delay focus to next runloop so the TextField is rendered first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isFocused = true
        }
    }

    private func cancel() {
        isEditing = false
    }

    private func save() {
        guard isEditing else { return }
        isEditing = false

        let newValue = editValue.trimmingCharacters(in: .whitespaces)
        if newValue == value { return }

        guard let rawYAML = store.readRawYAML(for: runbook) else { return }

        let updatedYAML = replaceYAMLValue(in: rawYAML, label: label, oldValue: value, newValue: newValue)
        guard updatedYAML != rawYAML else { return }

        guard let path = runbook.filePath else { return }
        let filename = (path as NSString).lastPathComponent
        try? store.saveRaw(updatedYAML, to: filename)
        store.loadAll()
    }

    /// Replace a YAML value, scoped to lines containing the label key.
    private func replaceYAMLValue(in yaml: String, label: String, oldValue: String, newValue: String) -> String {
        // Clean up the label (remove trailing spaces and arrows)
        let cleanLabel = label
            .replacingOccurrences(of: " → ", with: "")
            .replacingOccurrences(of: "header: ", with: "")
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ":", with: "")

        let lines = yaml.components(separatedBy: "\n")
        var result: [String] = []

        var replaced = false
        for line in lines {
            // Match lines that contain both the label key and the old value
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !replaced && trimmed.contains(oldValue) &&
                (cleanLabel.isEmpty || trimmed.lowercased().hasPrefix(cleanLabel.lowercased())) {
                let updated = line.replacingOccurrences(of: oldValue, with: newValue,
                                                         options: [], range: line.range(of: oldValue))
                result.append(updated)
                replaced = true
            } else {
                result.append(line)
            }
        }

        // Fallback: just replace first occurrence anywhere
        if !replaced {
            return yaml.replacingOccurrences(of: oldValue, with: newValue,
                                              options: [], range: yaml.range(of: oldValue))
        }

        return result.joined(separator: "\n")
    }
}
