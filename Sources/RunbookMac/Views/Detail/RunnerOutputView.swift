import SwiftUI
import AppKit

struct RunnerOutputView: View {
    let runbookName: String
    var runStartedAt: Date?
    @Binding var output: [String]
    /// When non-nil, a Stop button appears in the toolbar near Copy All.
    /// Fires the closure to request cancellation without dismissing the
    /// session (the tab × handles stop+dismiss atomically).
    var stopAction: (() -> Void)? = nil
    /// When non-nil, a Retry button appears in the toolbar. Intended for
    /// terminal sessions so the user can rerun with the same args. The
    /// closure receives the current state of the inline Dry toggle so the
    /// caller knows whether to run real or dry.
    var retryAction: ((_ dryRun: Bool) -> Void)? = nil
    /// Initial value of the inline Dry toggle that sits next to Retry. Pass
    /// the session's `dryRun` so the default matches the prior run.
    var retryInitialDryRun: Bool = false
    @State private var retryDryRun: Bool = false
    @State private var retryDryRunPrimed = false
    @State private var searchText = ""
    @State private var showSearch = false
    @State private var currentMatch = 0
    @FocusState private var searchFocused: Bool

    private var outputText: String {
        output.joined(separator: "\n")
    }

    private var matchingLines: [Int] {
        guard !searchText.isEmpty else { return [] }
        return output.indices.filter {
            output[$0].localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar — always visible while a Stop action is wired so the
            // user can interrupt even before the first output line lands.
            if !output.isEmpty || stopAction != nil {
                toolbar
                Divider()
            }

            // Search bar
            if showSearch {
                searchBar
                Divider()
            }

            // Output lines
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(output.enumerated()), id: \.offset) { idx, line in
                            outputLine(idx: idx, line: line)
                                .id(idx)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: output.count) {
                    if !showSearch, let last = output.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
                .onChange(of: currentMatch) {
                    if !matchingLines.isEmpty {
                        let idx = matchingLines[currentMatch]
                        proxy.scrollTo(idx, anchor: .center)
                    }
                }
            }
            .background(.black.opacity(0.03))
        }
        .onAppear {
            if !retryDryRunPrimed {
                retryDryRun = retryInitialDryRun
                retryDryRunPrimed = true
            }
        }
        .onChange(of: retryInitialDryRun) {
            // Reset the toggle if the caller switches to a different session.
            retryDryRun = retryInitialDryRun
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button {
                showSearch.toggle()
                if showSearch {
                    searchFocused = true
                } else {
                    searchText = ""
                }
            } label: {
                Label("Find", systemImage: "magnifyingglass")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("f", modifiers: .command)

            Spacer()

            Text("\(output.count) lines")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(outputText, forType: .string)
            } label: {
                Label("Copy All", systemImage: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.borderless)

            if let stopAction {
                Button(role: .destructive) {
                    stopAction()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .tint(.red)
                .help("Stop the run (keeps the tab open)")
                .keyboardShortcut(".", modifiers: .command)
            }

            if let retryAction {
                Toggle("Dry", isOn: $retryDryRun)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .help("Toggle to rerun as a dry run vs. a real run")

                Button {
                    retryAction(retryDryRun)
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Rerun this runbook with the same variables")
            }

            Button {
                saveToFile()
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.bar)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            FilterField(placeholder: "Search output",
                        text: $searchText,
                        onCommit: { nextMatch() })

            if !searchText.isEmpty {
                Text(matchingLines.isEmpty
                     ? "No matches"
                     : "\(currentMatch + 1) of \(matchingLines.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 70)

                Button(action: previousMatch) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .disabled(matchingLines.isEmpty)

                Button(action: nextMatch) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .disabled(matchingLines.isEmpty)
            }

            Button {
                showSearch = false
                searchText = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .onChange(of: searchText) {
            currentMatch = 0
        }
    }

    // MARK: - Output Line

    @ViewBuilder
    private func outputLine(idx: Int, line: String) -> some View {
        let isMatch = !searchText.isEmpty && line.localizedCaseInsensitiveContains(searchText)
        let isCurrentMatch = isMatch && matchingLines.indices.contains(currentMatch) && matchingLines[currentMatch] == idx
        let highlight = OutputHighlighter.color(for: line)

        let attr = OutputHighlighter.attributedLine(for: line, baseColor: highlight.color)
        let hasLink = attr.runs.contains { $0.link != nil }

        Text(attr)
            .font(.system(.caption, design: .monospaced))
            .fontWeight(highlight.bold ? .bold : .regular)
            .textSelection(.enabled)
            .padding(.horizontal, isMatch ? 4 : 0)
            .padding(.vertical, isMatch ? 1 : 0)
            .background(
                isCurrentMatch ? Color.yellow.opacity(0.3) :
                isMatch ? Color.yellow.opacity(0.1) : .clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .pointerStyle(hasLink ? .link : nil)
    }

    private func nextMatch() {
        guard !matchingLines.isEmpty else { return }
        currentMatch = (currentMatch + 1) % matchingLines.count
    }

    private func previousMatch() {
        guard !matchingLines.isEmpty else { return }
        currentMatch = (currentMatch - 1 + matchingLines.count) % matchingLines.count
    }

    // MARK: - Save

    private func saveToFile() {
        let logsDir = AppSettings.logsURL
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

        let timestamp = ISO8601DateFormatter.string(
            from: Date(),
            timeZone: .current,
            formatOptions: [.withFullDate, .withTime, .withDashSeparatorInDate]
        ).replacingOccurrences(of: ":", with: "-")

        let panel = NSSavePanel()
        panel.directoryURL = logsDir
        panel.nameFieldStringValue = "\(runbookName)-\(timestamp).log"
        panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try outputText.write(to: url, atomically: true, encoding: .utf8)
                if let startedAt = runStartedAt {
                    LogIndex.record(
                        runbookName: runbookName,
                        date: startedAt,
                        logPath: url.path
                    )
                }
            } catch {
                output.append("Save failed: \(error.localizedDescription)")
            }
        }
    }

    func resetSearch() {
        showSearch = false
        searchText = ""
    }
}
