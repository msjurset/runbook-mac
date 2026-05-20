import Foundation
import AppKit
import VimEngine

/// Per-editor mode that hands the keyboard off to `VimEngine`. `nil` =
/// no mode active (normal typing). Kept as an enum (not a Bool) so
/// future modes can be added without churn.
enum TextMode: String, Hashable {
    case vim

    var badge: String {
        switch self {
        case .vim: return "VIM"
        }
    }
}

/// A slash command pill in the in-editor dropdown. Today there's only
/// `/vim`; the enum is here so adding future commands (`/uc`, templates)
/// doesn't reshape the call sites.
enum SlashCommand: Identifiable, Hashable {
    case mode(ModeCommand)

    var name: String {
        switch self {
        case .mode(let m): return m.name
        }
    }

    var hint: String {
        switch self {
        case .mode(let m): return m.description
        }
    }

    var id: String { name }
}

struct ModeCommand: Identifiable, Hashable {
    let name: String
    let description: String
    let mode: TextMode

    var id: String { name }
}

let builtInSlashCommands: [SlashCommand] = [
    .mode(ModeCommand(name: "vim",
                      description: "vim keybindings",
                      mode: .vim)),
]

/// Helpers for prefix matching and `//cmd` escape rewriting at save time.
enum SlashCommandRegistry {
    static let all: [SlashCommand] = builtInSlashCommands

    static func match(prefix: String) -> [SlashCommand] {
        var needle = prefix
        while needle.hasPrefix("/") { needle.removeFirst() }
        let lower = needle.lowercased()
        if lower.isEmpty { return all }
        return all.filter { $0.name.lowercased().hasPrefix(lower) }
    }

    static func exactMatch(prefix: String) -> SlashCommand? {
        var needle = prefix
        while needle.hasPrefix("/") { needle.removeFirst() }
        let lower = needle.lowercased()
        return all.first { $0.name.lowercased() == lower }
    }

    /// Characters allowed inside a slash-command name.
    static func isNameCharacter(_ c: Character) -> Bool {
        c.isLetter || c.isNumber || c == "_" || c == "-"
    }
}

/// Detect the `/partial` run ending at the caret. Shared by every
/// Coordinator that exposes a slash binding — the logic is identical
/// across editors so it doesn't belong duplicated three times.
///
/// Returns the prefix including the leading `/`, or the empty string
/// when no slash run is at the caret. `//` is treated as an escape
/// (typed-literal-slash) and suppresses detection so users typing
/// paths like `https://…` don't trigger the dropdown.
@MainActor
enum SlashPrefixDetector {
    static func detect(in textView: NSTextView) -> String {
        let cursor = textView.selectedRange().location
        let ns = textView.string as NSString
        guard cursor > 0, cursor <= ns.length else { return "" }

        var i = cursor - 1
        while i >= 0 {
            let ch = ns.character(at: i)
            guard let scalar = Unicode.Scalar(ch) else { return "" }
            if scalar == "/" {
                if i > 0, ns.character(at: i - 1) == 0x2F { return "" }
                return ns.substring(with: NSRange(location: i, length: cursor - i))
            } else if SlashCommandRegistry.isNameCharacter(Character(scalar)) {
                i -= 1
            } else {
                return ""
            }
        }
        return ""
    }
}
