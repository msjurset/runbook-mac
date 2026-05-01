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
    /// Bump to request focus on the FilterField after we flip into edit
    /// mode. A FocusState binding doesn't reach into NSViewRepresentable.
    @State private var focusBump = 0

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
                // Multi-line by design: command/shell values that start as
                // one-liners often grow into multi-line shell snippets, so
                // plain Return inserts a newline; Cmd+Return saves; Escape
                // cancels; clicking outside saves via textDidEndEditing.
                InlineMultilineEditor(
                    text: $editValue,
                    onSave: { save() },
                    onCancel: { cancel() },
                    focusTrigger: focusBump
                )
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
        // Bump the trigger so FilterField becomes first responder after the
        // SwiftUI render flushes the .editing branch into the view tree.
        focusBump += 1
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

        let oldIsBlock = value.contains("\n")
        // Whether the NEW value is genuinely multi-line: collapse trailing
        // whitespace/newlines first so a stray "user pressed Return at end"
        // doesn't keep the value pinned in block-scalar form when its body
        // is really just one line.
        let newBodyTrimmed = editValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let newIsBlock = newBodyTrimmed.contains("\n")

        // Block scalars preserve internal whitespace; inline values trim
        // outer whitespace (YAML's flat form doesn't preserve it anyway).
        let newValue: String = newIsBlock ? editValue : newBodyTrimmed
        if newValue == value { return }

        guard let rawYAML = store.readRawYAML(for: runbook) else {
            saveError = "Could not read YAML source file."
            return
        }

        let updatedYAML: String
        switch (oldIsBlock, newIsBlock) {
        case (true, true):
            // Block → block: edit the block scalar contents in place.
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

        case (false, true):
            // Inline → block: promote `key: value` to `key: |` with
            // indented body. Next render will switch this row to the
            // CodeBlockView/popout.
            if let updated = promoteInlineToBlock(in: rawYAML,
                                                  label: label,
                                                  oldValue: value,
                                                  newValue: newValue,
                                                  stepName: stepName) {
                updatedYAML = updated
            } else {
                saveError = "Couldn't locate the inline value in the YAML (step: \(stepName ?? "?"), key: \(label)). Edit was not saved."
                return
            }

        case (true, false):
            // Block → inline: demote `key: |\n  body` back to flat
            // `key: body`. Without this branch the block scalar header
            // stays even after the user collapses the body to one line,
            // so the row keeps rendering as a CodeBlockView.
            if let updated = demoteBlockToInline(in: rawYAML,
                                                 label: label,
                                                 newValue: newValue,
                                                 stepName: stepName) {
                updatedYAML = updated
            } else {
                saveError = "Couldn't locate the block in the YAML (step: \(stepName ?? "?"), key: \(label)). Edit was not saved."
                return
            }

        case (false, false):
            // Flat → flat.
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

    /// Convert an inline `key: value` line into a block-scalar `key: |` with
    /// indented content. Used when the user pastes / types newlines into a
    /// previously single-line field. Scopes by step name when provided so
    /// multiple steps sharing the same key (e.g. every shell step has
    /// `command:`) don't collide on the first match.
    private func promoteInlineToBlock(in yaml: String, label: String, oldValue: String, newValue: String, stepName: String?) -> String? {
        let key = label.lowercased()
            .replacingOccurrences(of: " → ", with: "")
            .replacingOccurrences(of: "header: ", with: "")
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ":", with: "")
        guard !key.isEmpty else { return nil }

        let lines = yaml.components(separatedBy: "\n")
        let scope = stepLineRange(in: lines, stepName: stepName)

        var targetIdx: Int? = nil
        var indentStr = ""
        for idx in scope {
            let line = lines[idx]
            let leading = line.prefix(while: { $0 == " " || $0 == "\t" })
            let afterLeading = String(line.dropFirst(leading.count))
            guard afterLeading.hasPrefix("\(key):") else { continue }
            let afterKey = afterLeading
                .dropFirst(key.count + 1)
                .trimmingCharacters(in: .whitespaces)
            // The displayed `value` mirrors what was rendered, which strips
            // YAML quotes. Match against the bare value as well as both
            // quote styles so `command: "echo hi"` still matches when the
            // user's edit started from displayed `echo hi`.
            let matches = afterKey == oldValue
                || afterKey == "\"\(oldValue)\""
                || afterKey == "'\(oldValue)'"
            if matches {
                targetIdx = idx
                indentStr = String(leading)
                break
            }
        }
        guard let idx = targetIdx else { return nil }

        let blockIndent = indentStr + "  "
        var replacement: [String] = ["\(indentStr)\(key): |"]
        for line in newValue.components(separatedBy: "\n") {
            replacement.append(line.isEmpty ? "" : blockIndent + line)
        }
        var result = lines
        result.replaceSubrange(idx...idx, with: replacement)
        return result.joined(separator: "\n")
    }

    /// Inverse of promoteInlineToBlock: collapse a block scalar (`key: |`
    /// plus its indented body lines) back into a single inline `key: value`
    /// line. Quotes the value when YAML's plain-scalar rules would mis-parse
    /// it (leading reserved chars, embedded `: ` or ` #`, reserved keywords,
    /// numeric-like text).
    private func demoteBlockToInline(in yaml: String, label: String, newValue: String, stepName: String?) -> String? {
        let key = label.lowercased()
            .replacingOccurrences(of: " → ", with: "")
            .replacingOccurrences(of: "header: ", with: "")
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ":", with: "")
        guard !key.isEmpty else { return nil }

        let lines = yaml.components(separatedBy: "\n")
        let scope = stepLineRange(in: lines, stepName: stepName)

        // Find the block-scalar header `<indent>key: |` (plus folded /
        // chomping variants).
        var headerIdx: Int? = nil
        var indentStr = ""
        for idx in scope {
            let line = lines[idx]
            let leading = line.prefix(while: { $0 == " " || $0 == "\t" })
            let afterLeading = String(line.dropFirst(leading.count))
            guard afterLeading.hasPrefix("\(key):") else { continue }
            let afterKey = afterLeading
                .dropFirst(key.count + 1)
                .trimmingCharacters(in: .whitespaces)
            if ["|", "|-", "|+", ">", ">-", ">+"].contains(afterKey) {
                headerIdx = idx
                indentStr = String(leading)
                break
            }
        }
        guard let hIdx = headerIdx else { return nil }

        // Block content runs from hIdx+1 until indent drops below the body's
        // first-content indent (matches replaceBlockScalarValue's scan).
        var blockEnd = hIdx + 1
        var bodyIndent: Int? = nil
        while blockEnd < lines.count {
            let line = lines[blockEnd]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                blockEnd += 1
                continue
            }
            let leadingLen = line.prefix(while: { $0 == " " || $0 == "\t" }).count
            if let b = bodyIndent {
                if leadingLen < b { break }
            } else {
                bodyIndent = leadingLen
            }
            blockEnd += 1
        }

        let inlineLine = "\(indentStr)\(key): \(formatInlineYAMLValue(newValue))"
        var result = lines
        result.replaceSubrange(hIdx..<blockEnd, with: [inlineLine])
        return result.joined(separator: "\n")
    }

    /// Quote `value` for use as a YAML inline scalar if its plain form
    /// would be ambiguous or mis-parsed. Pragmatic, not a full YAML 1.2
    /// scalar-resolution implementation — it covers the cases that bite
    /// shell command bodies, which is what flows through here.
    private func formatInlineYAMLValue(_ value: String) -> String {
        let needsQuote: Bool = {
            if value.isEmpty { return true }
            if value.first?.isWhitespace == true { return true }
            if value.last?.isWhitespace == true { return true }
            if let first = value.first, "!&*?|>%@`-,[]{}#".contains(first) { return true }
            if value.contains(": ") || value.contains(" #") { return true }
            let lower = value.lowercased()
            if ["null", "~", "true", "false", "yes", "no", "on", "off"].contains(lower) { return true }
            if Double(value) != nil { return true }
            return false
        }()
        if !needsQuote { return value }
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    /// Lines belonging to the named step's `- name: <stepName>` block,
    /// bounded by the next sibling-or-shallower `- name:`. Falls back to
    /// the whole file when stepName is nil or no match is found, so
    /// callers can still operate at file scope.
    private func stepLineRange(in lines: [String], stepName: String?) -> Range<Int> {
        guard let stepName else { return 0..<lines.count }
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
            return 0..<lines.count
        }
        let headerIndent = lines[headerIdx].prefix { $0 == " " || $0 == "\t" }.count
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
