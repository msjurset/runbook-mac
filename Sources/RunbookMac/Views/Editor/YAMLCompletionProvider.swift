import Foundation

/// Provides context-aware YAML completions for runbook schema.
struct YAMLCompletionProvider {
    /// Returns completion suggestions based on the current line context.
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

        // Step-level keys
        if indent >= 4 {
            // Inside a step
            if trimmed.isEmpty || !trimmed.contains(":") {
                return filterPrefix(stepKeys, trimmed)
            }
            // Step type values
            if trimmed.hasPrefix("type:") {
                return ["shell", "ssh", "http"]
            }
            if trimmed.hasPrefix("on_error:") {
                return ["abort", "continue", "retry"]
            }
            // Shell step keys
            if indent >= 6 {
                return filterPrefix(shellKeys + sshKeys + httpKeys, trimmed)
            }
        }

        // Notify / log section
        if indent == 2 {
            if trimmed.hasPrefix("mode:") {
                return ["new", "append"]
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
}
