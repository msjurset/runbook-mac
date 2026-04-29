import AppKit
import SwiftUI

enum CodeLanguage {
    case bash
    case json
    case plain
}

/// Display-only code block: monospace, subtle background, syntax-highlighted,
/// soft-wrapped with a hanging indent so wrapped lines align under the first
/// non-whitespace character of the source line. Uses a MUTED palette — the
/// editor uses full-vibrancy colors so the eye is drawn there when editing.
struct CodeBlockView: View {
    let source: String
    let language: CodeLanguage
    /// Smaller for inline display; popout editor uses 12pt.
    var fontSize: CGFloat = 10
    /// Fraction of original alpha applied to every highlighted token
    /// (`labelColor` is kept at full alpha so normal text stays readable).
    var muteAlpha: CGFloat = 0.55
    /// `true` (default) wraps long lines under a hanging indent. `false` keeps
    /// each line on a single horizontal axis — pair with a horizontal ScrollView
    /// so the user can scroll wide commands instead of having them reflow.
    var wrapsLines: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(source.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                row(for: line)
            }
        }
        .padding(8)
        .frame(maxWidth: wrapsLines ? .infinity : nil, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(NSColor.textBackgroundColor).opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func row(for line: String) -> some View {
        let leadingCount = line.prefix { $0 == " " || $0 == "\t" }.count
        let rest = String(line.dropFirst(leadingCount))
        let indent = CGFloat(leadingCount) * monoCharWidth(fontSize)

        Text(highlighted(rest))
            .font(.system(size: fontSize, weight: .regular, design: .monospaced))
            .textSelection(.enabled)
            .lineLimit(wrapsLines ? nil : 1)
            .fixedSize(horizontal: !wrapsLines, vertical: true)
            .padding(.leading, indent)
            .frame(maxWidth: wrapsLines ? .infinity : nil, alignment: .leading)
    }

    private func highlighted(_ lineText: String) -> AttributedString {
        let ns = NSMutableAttributedString(string: lineText)
        switch language {
        case .bash:  BashHighlighter.apply(to: ns)
        case .json:  JSONHighlighter.apply(to: ns)
        case .plain: break
        }
        muteColors(ns, factor: muteAlpha)
        return AttributedString(ns)
    }

    /// Reduce every non-base foreground color's alpha. The base labelColor is
    /// passed through so normal (non-highlighted) text stays fully visible.
    private func muteColors(_ ns: NSMutableAttributedString, factor: CGFloat) {
        let full = NSRange(location: 0, length: ns.length)
        let base = NSColor.labelColor
        ns.enumerateAttribute(.foregroundColor, in: full, options: []) { value, range, _ in
            guard let color = value as? NSColor, !isSameColor(color, base) else { return }
            ns.addAttribute(.foregroundColor,
                            value: color.withAlphaComponent(color.alphaComponent * factor),
                            range: range)
        }
    }

    private func isSameColor(_ a: NSColor, _ b: NSColor) -> Bool {
        // Compare in sRGB for stability; both base and highlighter colors are
        // system colors that are dynamic but resolvable to concrete sRGB values.
        guard let ar = a.usingColorSpace(.sRGB), let br = b.usingColorSpace(.sRGB) else {
            return a == b
        }
        let eps: CGFloat = 0.002
        return abs(ar.redComponent - br.redComponent) < eps &&
               abs(ar.greenComponent - br.greenComponent) < eps &&
               abs(ar.blueComponent - br.blueComponent) < eps
    }

    /// Pixel width of a monospace character at a given size.
    private func monoCharWidth(_ size: CGFloat) -> CGFloat {
        let font = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        return ("M" as NSString).size(withAttributes: [.font: font]).width
    }
}

// MARK: - Palette

/// Inspired by Tokyo Night / Xcode Default Dark. Semantic groups match the
/// TextMate / Tree-sitter vocabulary (@keyword, @string, @operator, etc.).
enum CodeColors {
    static let keyword  = NSColor.systemPurple
    static let string   = NSColor.systemGreen.withAlphaComponent(0.75)
    static let comment  = NSColor.systemGray
    static let number   = NSColor.systemYellow
    static let bool     = NSColor.systemPurple
    static let variable = NSColor.systemTeal
    static let template = NSColor.systemPink
    static let op       = NSColor.systemOrange
    static let builtin  = NSColor.systemBlue
}

// MARK: - Highlighters

/// Each highlighter exposes two entry points:
///   • `apply(to:)` — paints directly into an existing NSMutableAttributedString
///     (used by the live NSTextView editor).
///   • `highlightedString(_:)` — returns a fresh AttributedString (used by Text).

enum BashHighlighter {
    static func apply(to storage: NSMutableAttributedString) {
        let full = NSRange(location: 0, length: storage.length)
        storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: full)

        paint(#"\b(if|then|else|elif|fi|for|in|do|done|while|until|case|esac|function|return|break|continue|local|export|readonly|unset|declare|typeset)\b"#,
              on: storage, color: CodeColors.keyword)
        paint(#"\b(curl|jq|echo|printf|cat|grep|sed|awk|tr|xargs|sleep|test|date|head|tail|wc|cut|sort|uniq|find|mkdir|rm|cp|mv|ls|chmod|chown|ssh|scp|rsync|goback|runbook|op)\b"#,
              on: storage, color: CodeColors.builtin)
        paint(#"(?<![A-Za-z_])\d+(?:\.\d+)?(?![A-Za-z_])"#, on: storage, color: CodeColors.number)
        paint(#"\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_]*|\$[0-9@?#*$!-]"#, on: storage, color: CodeColors.variable)
        // Operators first so string color overrides any pipe-in-string.
        paint(#"\|\||&&|>>|<<|==|!=|<=|>=|\||>|<|&(?!&)"#, on: storage, color: CodeColors.op)
        paint(#""(?:\\.|[^"\\])*""#, on: storage, color: CodeColors.string)
        // Single-quoted strings only single-line — lets multi-line embedded DSLs
        // (jq, awk, sed) render with their own structure, not as one green blob.
        paint(#"'[^'\n]*'"#, on: storage, color: CodeColors.string)
        paint(#"(?m)(?:^|[ \t])#.*$"#, on: storage, color: CodeColors.comment)
        // Templates last — they light up even inside strings.
        paint(#"\{\{[^}]*\}\}"#, on: storage, color: CodeColors.template)
    }

    static func highlightedString(_ source: String) -> AttributedString {
        let ns = NSMutableAttributedString(string: source)
        apply(to: ns)
        return AttributedString(ns)
    }
}

enum JSONHighlighter {
    static func apply(to storage: NSMutableAttributedString) {
        let full = NSRange(location: 0, length: storage.length)
        storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: full)

        paint(#"(?<![A-Za-z_"])-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?(?![A-Za-z_"])"#,
              on: storage, color: CodeColors.number)
        paint(#"\b(true|false|null)\b"#, on: storage, color: CodeColors.bool)
        paint(#""(?:\\.|[^"\\])*""#, on: storage, color: CodeColors.string)
        paint(#""(?:\\.|[^"\\])*"(?=\s*:)"#, on: storage, color: CodeColors.keyword)
        paint(#"\{\{[^}]*\}\}"#, on: storage, color: CodeColors.template)
    }

    static func highlightedString(_ source: String) -> AttributedString {
        let ns = NSMutableAttributedString(string: source)
        apply(to: ns)
        return AttributedString(ns)
    }
}

private func paint(_ pattern: String, on storage: NSMutableAttributedString, color: NSColor) {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
    let full = NSRange(location: 0, length: storage.length)
    regex.enumerateMatches(in: storage.string, options: [], range: full) { match, _, _ in
        if let r = match?.range {
            storage.addAttribute(.foregroundColor, value: color, range: r)
        }
    }
}
