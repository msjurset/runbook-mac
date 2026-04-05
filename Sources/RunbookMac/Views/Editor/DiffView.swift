import SwiftUI

struct DiffView: View {
    let original: String
    let modified: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var diffLines: [DiffLine] {
        computeDiff(original: original, modified: modified)
    }

    private var hasChanges: Bool {
        diffLines.contains { $0.kind != .unchanged }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Review Changes")
                    .font(.headline)
                Spacer()
                if !hasChanges {
                    Text("No changes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(diffLines.enumerated()), id: \.offset) { _, line in
                        diffLineView(line)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.system(.caption, design: .monospaced))

            Divider()

            HStack {
                Button("Back to Editor") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { onConfirm() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!hasChanges)
            }
            .padding()
        }
    }

    @ViewBuilder
    private func diffLineView(_ line: DiffLine) -> some View {
        HStack(spacing: 0) {
            Text(line.prefix)
                .foregroundStyle(line.prefixColor)
                .frame(width: 16, alignment: .center)
            Text(line.text)
                .foregroundStyle(line.textColor)
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(line.background)
    }
}

// MARK: - Diff computation

enum DiffKind {
    case unchanged, added, removed
}

struct DiffLine {
    let kind: DiffKind
    let text: String

    var prefix: String {
        switch kind {
        case .unchanged: return " "
        case .added: return "+"
        case .removed: return "-"
        }
    }

    var prefixColor: Color {
        switch kind {
        case .unchanged: return .secondary
        case .added: return .green
        case .removed: return .red
        }
    }

    var textColor: Color {
        switch kind {
        case .unchanged: return .primary
        case .added: return .green
        case .removed: return .red
        }
    }

    var background: Color {
        switch kind {
        case .unchanged: return .clear
        case .added: return .green.opacity(0.08)
        case .removed: return .red.opacity(0.08)
        }
    }
}

/// Simple line-based diff using longest common subsequence.
func computeDiff(original: String, modified: String) -> [DiffLine] {
    let oldLines = original.components(separatedBy: "\n")
    let newLines = modified.components(separatedBy: "\n")

    let lcs = longestCommonSubsequence(oldLines, newLines)
    var result: [DiffLine] = []

    var oi = 0, ni = 0, li = 0
    while oi < oldLines.count || ni < newLines.count {
        if li < lcs.count {
            // Emit removals (old lines not in LCS)
            while oi < oldLines.count && oldLines[oi] != lcs[li] {
                result.append(DiffLine(kind: .removed, text: oldLines[oi]))
                oi += 1
            }
            // Emit additions (new lines not in LCS)
            while ni < newLines.count && newLines[ni] != lcs[li] {
                result.append(DiffLine(kind: .added, text: newLines[ni]))
                ni += 1
            }
            // Emit common line
            if oi < oldLines.count && ni < newLines.count {
                result.append(DiffLine(kind: .unchanged, text: lcs[li]))
                oi += 1
                ni += 1
                li += 1
            }
        } else {
            // Remaining old lines are removals
            while oi < oldLines.count {
                result.append(DiffLine(kind: .removed, text: oldLines[oi]))
                oi += 1
            }
            // Remaining new lines are additions
            while ni < newLines.count {
                result.append(DiffLine(kind: .added, text: newLines[ni]))
                ni += 1
            }
        }
    }

    return result
}

private func longestCommonSubsequence(_ a: [String], _ b: [String]) -> [String] {
    let m = a.count, n = b.count
    var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

    for i in 1...m {
        for j in 1...n {
            if a[i - 1] == b[j - 1] {
                dp[i][j] = dp[i - 1][j - 1] + 1
            } else {
                dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
            }
        }
    }

    var result: [String] = []
    var i = m, j = n
    while i > 0 && j > 0 {
        if a[i - 1] == b[j - 1] {
            result.append(a[i - 1])
            i -= 1
            j -= 1
        } else if dp[i - 1][j] > dp[i][j - 1] {
            i -= 1
        } else {
            j -= 1
        }
    }
    return result.reversed()
}
