import SwiftUI

struct EditableConfigRow: View {
    let label: String
    let value: String
    let runbook: Runbook
    let store: RunbookStore
    /// When set, block-scalar replacement is scoped to the YAML block that
    /// follows `- name: <stepName>`. Without this, multiple steps sharing a
    /// key (e.g. every shell step has `command: |`) collide on save.
    var stepName: String? = nil

    @State private var isEditing = false
    @State private var isPopoutOpen = false
    @State private var editValue: String = ""
    @State private var saveError: String?
    @FocusState private var isFocused: Bool

    private var lineCount: Int {
        max(1, editValue.components(separatedBy: "\n").count)
    }

    private var editorHeight: CGFloat {
        let lines = min(lineCount, 10)
        return CGFloat(lines) * 16 + 12
    }

    private var isMultiline: Bool { value.contains("\n") }

    private var codeLanguage: CodeLanguage? {
        guard isMultiline else { return nil }
        let clean = label.lowercased().trimmingCharacters(in: .whitespaces)
        if clean == "command" { return .bash }
        if clean == "body" {
            let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.hasPrefix("{") || t.hasPrefix("[") { return .json }
            return .plain
        }
        return .plain
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 70, alignment: .trailing)

            if isEditing {
                TextEditor(text: $editValue)
                    .font(.system(.caption, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.background)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(.blue.opacity(0.5), lineWidth: 1)
                    )
                    .frame(height: editorHeight)
                    .focused($isFocused)
                    .onChange(of: isFocused) {
                        if !isFocused { save() }
                    }
                    .onExitCommand { cancel() }
            } else if let lang = codeLanguage {
                CodeBlockView(source: value, language: lang)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { startPopoutEditing() }
                    .help("Double-click anywhere to edit")
                    .popover(isPresented: $isPopoutOpen, arrowEdge: .top) {
                        CodePopoutEditor(text: $editValue, language: lang)
                            .frame(width: 900, height: 520)
                            .onDisappear { save() }
                    }
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
        .alert("Save Error", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK") { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    private func startEditing() {
        editValue = value
        isEditing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isFocused = true
        }
    }

    private func startPopoutEditing() {
        editValue = value
        isPopoutOpen = true
    }

    private func cancel() {
        isEditing = false
        isPopoutOpen = false
    }

    private func save() {
        // Exit any active edit state; downstream write is idempotent.
        isEditing = false
        isPopoutOpen = false

        // Multi-line block scalars preserve whitespace intentionally; only trim
        // for single-line inline values.
        let isBlockScalar = value.contains("\n") || editValue.contains("\n")
        let newValue = isBlockScalar ? editValue : editValue.trimmingCharacters(in: .whitespaces)
        if newValue == value { return }

        guard let rawYAML = store.readRawYAML(for: runbook) else {
            saveError = "Could not read YAML source file."
            return
        }

        let updatedYAML: String
        if isBlockScalar {
            if let updated = replaceBlockScalarValue(in: rawYAML,
                                                     label: label,
                                                     oldValue: value,
                                                     newValue: newValue,
                                                     stepName: stepName) {
                updatedYAML = updated
            } else {
                saveError = "Couldn't locate this block in the YAML (step: \(stepName ?? "?"), key: \(label)). Edit was not saved."
                return
            }
        } else {
            updatedYAML = replaceYAMLValue(in: rawYAML, label: label, oldValue: value, newValue: newValue)
        }
        guard updatedYAML != rawYAML else {
            saveError = "Replacement produced no change. Edit was not saved."
            return
        }

        guard let path = runbook.filePath else {
            saveError = "Runbook has no file path."
            return
        }
        let filename = (path as NSString).lastPathComponent
        do {
            try store.saveRaw(updatedYAML, to: filename)
            store.loadAll()
        } catch {
            saveError = "Could not save: \(error.localizedDescription)"
        }
    }

    /// Replace a block-scalar value (e.g. `command: |`, `body: |`) with
    /// `newValue`, preserving the block's original indentation. Scopes by
    /// step name first (if provided); falls back to content-based disambig
    /// against `oldValue`.
    private func replaceBlockScalarValue(in yaml: String, label: String, oldValue: String, newValue: String, stepName: String?) -> String? {
        let key = label.lowercased()
            .replacingOccurrences(of: " → ", with: "")
            .replacingOccurrences(of: "header: ", with: "")
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ":", with: "")
        guard !key.isEmpty else { return nil }

        let lines = yaml.components(separatedBy: "\n")

        struct Block {
            let blockStart: Int       // first line after the header (may be blank)
            let firstContentIdx: Int
            let blockEnd: Int         // exclusive
            let blockIndent: String
        }

        // If stepName is provided, compute the line range owned by that step
        // (from `- name: <stepName>` up to the next `- name:` at the same or
        // lower indent). All candidate lookups are scoped inside that range.
        let scope: Range<Int> = {
            guard let stepName else { return 0..<lines.count }
            // Find the step header. `- name: <stepName>` may be quoted with ' or ".
            let nameMatch: (String) -> Bool = { line in
                let t = line.trimmingCharacters(in: .whitespaces)
                guard t.hasPrefix("- name:") else { return false }
                var rest = t.dropFirst("- name:".count).trimmingCharacters(in: .whitespaces)
                if (rest.hasPrefix("\"") && rest.hasSuffix("\"")) ||
                   (rest.hasPrefix("'") && rest.hasSuffix("'")) {
                    rest = String(rest.dropFirst().dropLast())
                }
                return rest == stepName
            }
            guard let headerIdx = lines.firstIndex(where: nameMatch) else {
                return 0..<lines.count // fall back to whole file
            }
            let headerIndent = lines[headerIdx].prefix { $0 == " " || $0 == "\t" }.count
            // Scan forward to the next `- name:` at indent <= headerIndent.
            var end = headerIdx + 1
            while end < lines.count {
                let l = lines[end]
                let t = l.trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("- name:") {
                    let indent = l.prefix { $0 == " " || $0 == "\t" }.count
                    if indent <= headerIndent { break }
                }
                end += 1
            }
            return headerIdx..<end
        }()

        // Collect every block-scalar whose key matches, within scope.
        var candidates: [Block] = []
        for idx in scope {
            let trimmed = lines[idx].trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\(key):") else { continue }
            let afterKey = trimmed.dropFirst(key.count + 1).trimmingCharacters(in: .whitespaces)
            let isBlockScalar = afterKey == "|" || afterKey == "|-" || afterKey == "|+"
                || afterKey == ">" || afterKey == ">-" || afterKey == ">+"
            guard isBlockScalar else { continue }

            let blockStart = idx + 1
            guard blockStart <= lines.count else { continue }

            var firstContentIdx = blockStart
            while firstContentIdx < lines.count
                    && lines[firstContentIdx].trimmingCharacters(in: .whitespaces).isEmpty {
                firstContentIdx += 1
            }
            guard firstContentIdx < lines.count else { continue }

            let blockIndent = String(lines[firstContentIdx].prefix { $0 == " " || $0 == "\t" })
            guard !blockIndent.isEmpty else { continue }

            var blockEnd = firstContentIdx
            while blockEnd < lines.count {
                let line = lines[blockEnd]
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    blockEnd += 1
                    continue
                }
                let indent = line.prefix { $0 == " " || $0 == "\t" }
                if indent.count < blockIndent.count { break }
                blockEnd += 1
            }

            candidates.append(Block(blockStart: blockStart,
                                    firstContentIdx: firstContentIdx,
                                    blockEnd: blockEnd,
                                    blockIndent: blockIndent))
        }

        // If step-name scoping left us exactly one candidate, use it —
        // that's the reliable path. Otherwise fall back to content matching
        // (strips block indent, compares against oldValue after trimming
        // trailing newlines on both sides to tolerate `|` vs `|-` differences).
        let match: Block?
        if candidates.count == 1 {
            match = candidates.first
        } else {
            let trimTrailingNewlines: (String) -> String = { s in
                var out = s
                while out.hasSuffix("\n") { out.removeLast() }
                return out
            }
            let targetOld = trimTrailingNewlines(oldValue)
            match = candidates.first { block in
                let slice = lines[block.firstContentIdx..<block.blockEnd]
                let stripped = slice.map { line -> String in
                    if line.isEmpty { return "" }
                    if line.hasPrefix(block.blockIndent) {
                        return String(line.dropFirst(block.blockIndent.count))
                    }
                    return line
                }.joined(separator: "\n")
                return trimTrailingNewlines(stripped) == targetOld
            }
        }

        guard let found = match else { return nil }

        let newBlockLines = newValue.components(separatedBy: "\n").map { line -> String in
            line.isEmpty ? "" : found.blockIndent + line
        }

        var result: [String] = []
        result.append(contentsOf: lines[0..<found.firstContentIdx])
        result.append(contentsOf: newBlockLines)
        if found.blockEnd < lines.count {
            result.append(contentsOf: lines[found.blockEnd..<lines.count])
        }
        return result.joined(separator: "\n")
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
