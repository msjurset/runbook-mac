import SwiftUI
import Yams

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
    nonisolated(unsafe) private static var cachedRules: [OutputHighlightRule]?

    static var rules: [OutputHighlightRule] {
        if let cached = cachedRules { return cached }
        let loaded = loadRules()
        cachedRules = loaded
        return loaded
    }

    static func reload() {
        cachedRules = nil
    }

    static func color(for line: String) -> (color: Color, bold: Bool) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        for rule in rules {
            if trimmed.range(of: rule.pattern, options: .regularExpression) != nil {
                return (rule.color, rule.bold)
            }
        }
        return (.primary, false)
    }

    // MARK: - Loading

    private static func loadRules() -> [OutputHighlightRule] {
        // Try user config first
        if let userRules = loadFromFile(configURL) {
            return userRules
        }
        // Fall back to built-in defaults
        return builtinRules
    }

    private static var configURL: URL {
        AppSettings.baseURL.appendingPathComponent("highlights.yaml")
    }

    private static func loadFromFile(_ url: URL) -> [OutputHighlightRule]? {
        guard let data = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        guard let yaml = try? Yams.load(yaml: data) as? [String: Any],
              let ruleList = yaml["rules"] as? [[String: Any]] else { return nil }

        var rules: [OutputHighlightRule] = []
        for entry in ruleList {
            guard let pattern = entry["pattern"] as? String,
                  let colorName = entry["color"] as? String else { continue }
            let bold = entry["bold"] as? Bool ?? false
            let color = parseColor(colorName)
            rules.append(OutputHighlightRule(pattern, color, bold: bold))
        }
        return rules.isEmpty ? nil : rules
    }

    private static func parseColor(_ name: String) -> Color {
        switch name.lowercased() {
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "orange": return .orange
        case "yellow": return Color(red: 0.95, green: 0.8, blue: 0.2)
        case "purple": return .purple
        case "cyan": return Color(red: 0.4, green: 0.8, blue: 0.9)
        case "gray", "grey", "secondary": return .gray
        case "white": return .white
        case "pink": return .pink
        case "teal": return .teal
        default:
            // Try hex color: "#RRGGBB"
            if name.hasPrefix("#"), name.count == 7 {
                let hex = String(name.dropFirst())
                if let val = UInt64(hex, radix: 16) {
                    let r = Double((val >> 16) & 0xFF) / 255.0
                    let g = Double((val >> 8) & 0xFF) / 255.0
                    let b = Double(val & 0xFF) / 255.0
                    return Color(red: r, green: g, blue: b)
                }
            }
            return .primary
        }
    }

    // MARK: - Built-in Defaults

    private static let builtinRules: [OutputHighlightRule] = [
        // Health check summary
        OutputHighlightRule(#"\[OK\]"#, .green),
        OutputHighlightRule(#"\[WARNING\]"#, .orange, bold: true),
        OutputHighlightRule(#"\[INFO\]"#, .blue),
        OutputHighlightRule(#"ACTION:"#, Color(red: 0.95, green: 0.8, blue: 0.2)),
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
        OutputHighlightRule(#"^.*==> "#, Color(red: 0.4, green: 0.8, blue: 0.9), bold: true),
        OutputHighlightRule(#"^.*🍺 "#, .green),
        OutputHighlightRule(#"^.*Removing:"#, .gray),
        OutputHighlightRule(#"^.*Upgrading "#, .blue),
        OutputHighlightRule(#"^.*Fetching "#, .blue),
        OutputHighlightRule(#"^.*Pouring "#, .gray),

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
}
