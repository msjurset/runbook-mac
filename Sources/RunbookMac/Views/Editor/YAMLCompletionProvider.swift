import Foundation

/// Provides context-aware YAML completions for runbook schema.
struct YAMLCompletionProvider {
    /// Returns completion suggestions based on the current line context.
    /// Both keys (filtered by the partial token before any colon) and values
    /// (filtered by the partial token after the colon) are returned already
    /// narrowed — AppKit displays exactly what we hand back.
    func completions(for line: String, cursorPosition: Int) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let indent = line.prefix(while: { $0 == " " }).count

        // Top-level keys
        if indent == 0 {
            return filterPrefix(topLevelKeys, trimmed)
        }

        // After "variables:" — variable definition keys
        if trimmed.hasPrefix("- ") && indent >= 2 {
            let afterDash = String(trimmed.dropFirst(2))
            return filterPrefix(variableKeys, afterDash)
        }

        // Step-level keys (indent 4 — direct children of a "- name:" entry
        // under steps:). MUST be checked before the deeper indent branch so
        // step-level keys don't bleed into shell/ssh/http sub-blocks.
        if indent == 4 {
            if trimmed.isEmpty || !trimmed.contains(":") {
                return filterPrefix(stepKeys, trimmed)
            }
            if trimmed.hasPrefix("type:") {
                return filterValues(["shell", "ssh", "http"], afterColonOf: trimmed)
            }
            if trimmed.hasPrefix("on_error:") {
                return filterValues(["abort", "continue", "retry"], afterColonOf: trimmed)
            }
            return []
        }

        // Sub-step keys (indent 6+ — keys nested under shell:/ssh:/http:
        // blocks: command:, dir:, host:, user:, port:, key_file:, agent_auth:,
        // method:, url:, headers:, body:).
        if indent >= 6 {
            if trimmed.isEmpty || !trimmed.contains(":") {
                return filterPrefix(shellKeys + sshKeys + httpKeys, trimmed)
            }
            return []
        }

        // Notify / log section (indent 2)
        if indent == 2 {
            if trimmed.hasPrefix("mode:") {
                return filterValues(["new", "append"], afterColonOf: trimmed)
            }
            return filterPrefix(notifyKeys + logKeys + variableDefKeys, trimmed)
        }

        return []
    }

    private let topLevelKeys = [
        "name:", "description:", "variables:", "steps:", "notify:", "log:",
    ]

    private let variableKeys = [
        "name:", "default:", "required:", "prompt:", "secret:",
    ]

    private let variableDefKeys = [
        "on:", "slack:", "desktop:", "email:", "macos:",
    ]

    private let stepKeys = [
        "- name:", "name:", "type:", "shell:", "ssh:", "http:",
        "condition:", "on_error:", "retries:", "timeout:",
        "parallel:", "confirm:", "capture:",
    ]

    private let shellKeys = [
        "command:", "dir:",
    ]

    private let sshKeys = [
        "host:", "user:", "port:", "key_file:", "command:", "agent_auth:",
    ]

    private let httpKeys = [
        "method:", "url:", "headers:", "body:",
    ]

    private let notifyKeys = [
        "on:", "slack:", "desktop:", "email:",
    ]

    private let logKeys = [
        "enabled:", "mode:", "dir:", "filename:",
    ]

    private func filterPrefix(_ candidates: [String], _ prefix: String) -> [String] {
        if prefix.isEmpty { return candidates }
        return candidates.filter { $0.lowercased().hasPrefix(prefix.lowercased()) }
    }

    /// For value-position completion: extract the partial value (the bit
    /// after `key:` on the line) and narrow the candidate set to entries
    /// that prefix-match it. This is what stops `type: ss` from offering
    /// `shell` or `http` alongside `ssh`.
    private func filterValues(_ values: [String], afterColonOf trimmed: String) -> [String] {
        guard let colonIdx = trimmed.firstIndex(of: ":") else { return values }
        let after = trimmed[trimmed.index(after: colonIdx)...]
            .trimmingCharacters(in: .whitespaces)
        if after.isEmpty { return values }
        return values.filter { $0.lowercased().hasPrefix(after.lowercased()) }
    }
}
