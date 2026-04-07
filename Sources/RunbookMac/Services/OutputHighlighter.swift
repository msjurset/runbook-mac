import SwiftUI

struct OutputHighlightRule {
    let pattern: String
    let color: Color
    let bold: Bool

    init(_ pattern: String, _ color: Color, bold: Bool = false) {
        self.pattern = pattern
        self.color = color
        self.bold = bold
    }
}

enum OutputHighlighter {
    static let rules: [OutputHighlightRule] = [
        // Health check summary
        OutputHighlightRule(#"^\s*\[OK\]"#, .green),
        OutputHighlightRule(#"^\s*\[WARNING\]"#, .orange, bold: true),
        OutputHighlightRule(#"^\s*\[INFO\]"#, .blue),
        OutputHighlightRule(#"^\s+ACTION:"#, .yellow),
        OutputHighlightRule(#"^[╔╚║]"#, .blue, bold: true),
        OutputHighlightRule(#"HEALTH CHECK SUMMARY"#, .blue, bold: true),

        // Step status markers (runbook CLI output)
        OutputHighlightRule(#"^[✓✔︎] "#, .green),
        OutputHighlightRule(#"^[✗×] "#, .red, bold: true),
        OutputHighlightRule(#"^▸ Step \d+"#, .blue, bold: true),
        OutputHighlightRule(#"^Running:"#, .blue, bold: true),
        OutputHighlightRule(#"done \(\d+"#, .green),

        // Errors and warnings (generic)
        OutputHighlightRule(#"(?i)^.*error[:!]"#, .red),
        OutputHighlightRule(#"(?i)^.*warning[:!]"#, .orange),
        OutputHighlightRule(#"(?i)^.*FAILED"#, .red, bold: true),

        // Homebrew
        OutputHighlightRule(#"^.*==> "#, .cyan, bold: true),
        OutputHighlightRule(#"^.*🍺 "#, .green),
        OutputHighlightRule(#"^.*Removing:"#, .secondary),
        OutputHighlightRule(#"^.*Upgrading "#, .blue),
        OutputHighlightRule(#"^.*Fetching "#, .blue),
        OutputHighlightRule(#"^.*Pouring "#, .secondary),

        // Pi-hole
        OutputHighlightRule(#"^\s*\[✓\]"#, .green),
        OutputHighlightRule(#"^\s*\[i\]"#, .blue),
        OutputHighlightRule(#"^\s*\[✗\]"#, .red),
        OutputHighlightRule(#"^\s*FTL "#, .purple),

        // SSH/connection
        OutputHighlightRule(#"(?i)connection refused"#, .red),
        OutputHighlightRule(#"(?i)permission denied"#, .red),
        OutputHighlightRule(#"(?i)timed? ?out"#, .orange),
    ]

    static func color(for line: String) -> (color: Color, bold: Bool) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        for rule in rules {
            if trimmed.range(of: rule.pattern, options: .regularExpression) != nil {
                return (rule.color, rule.bold)
            }
        }
        return (.primary, false)
    }
}

private extension Color {
    static let cyan = Color(red: 0.4, green: 0.8, blue: 0.9)
    static let yellow = Color(red: 0.95, green: 0.8, blue: 0.2)
    static let secondary = Color.gray
}
