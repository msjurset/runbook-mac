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

    @Test("Empty line at indent 6 returns step keys")
    func nestedEmptyLine() {
        // At indent 6 with empty content, returns step-level keys (not nested shell/ssh/http)
        let results = provider.completions(for: "      ", cursorPosition: 6)
        #expect(results.contains("type:"))
        #expect(results.contains("capture:"))
    }
}
