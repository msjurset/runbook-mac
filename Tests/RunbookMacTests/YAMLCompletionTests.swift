import Testing
@testable import RunbookMac

@Suite("YAML Completion Provider")
struct YAMLCompletionTests {
    let provider = YAMLCompletionProvider()

    @Test("Top-level completions on empty line")
    func topLevel() {
        let results = provider.completions(for: "", cursorPosition: 0)
        #expect(results.contains("name:"))
        #expect(results.contains("steps:"))
        #expect(results.contains("variables:"))
        #expect(results.contains("notify:"))
        #expect(results.contains("log:"))
    }

    @Test("Top-level completions with partial match")
    func topLevelPartial() {
        let results = provider.completions(for: "st", cursorPosition: 2)
        #expect(results.contains("steps:"))
        #expect(!results.contains("name:"))
    }

    @Test("Step type values")
    func stepTypes() {
        let results = provider.completions(for: "    type:", cursorPosition: 9)
        #expect(results.contains("shell"))
        #expect(results.contains("ssh"))
        #expect(results.contains("http"))
    }

    @Test("Error policy values")
    func errorPolicies() {
        let results = provider.completions(for: "    on_error:", cursorPosition: 12)
        #expect(results.contains("abort"))
        #expect(results.contains("continue"))
        #expect(results.contains("retry"))
    }

    @Test("Variable definition keys after dash")
    func variableKeys() {
        // "- " at indent 2+ triggers variable keys
        let results = provider.completions(for: "    - na", cursorPosition: 8)
        #expect(results.contains("name:"))
    }

    @Test("Step keys at indent level 4")
    func stepKeys() {
        let results = provider.completions(for: "    ", cursorPosition: 4)
        #expect(results.contains("type:"))
        #expect(results.contains("timeout:"))
        #expect(results.contains("on_error:"))
        #expect(results.contains("capture:"))
    }

    @Test("Empty line at indent 6 returns sub-step keys")
    func nestedEmptyLine() {
        // At indent 6 (under shell:/ssh:/http:) we now expect the
        // sub-step keys: command/dir for shell, host/user/port/key_file/
        // command/agent_auth for ssh, method/url/headers/body for http.
        // Step-level keys (type:, capture:, timeout:, ...) belong to
        // indent 4 only.
        let results = provider.completions(for: "      ", cursorPosition: 6)
        #expect(results.contains("command:"))
        #expect(results.contains("host:"))
        #expect(results.contains("url:"))
        #expect(!results.contains("type:"))
        #expect(!results.contains("capture:"))
    }

    @Test("Value completion filters by partial after colon")
    func valueFiltering() {
        // 'type: ss' should narrow to ssh only — not all three values.
        let results = provider.completions(for: "    type: ss", cursorPosition: 12)
        #expect(results == ["ssh"])
    }
}
