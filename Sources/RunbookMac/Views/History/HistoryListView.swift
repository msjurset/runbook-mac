import SwiftUI

struct HistoryListView: View {
    @Environment(RunbookStore.self) private var store
    @State private var filterName = ""

    private var filteredRecords: [HistoryRecord] {
        if filterName.isEmpty {
            return store.historyRecords
        }
        return store.historyRecords.filter {
            $0.runbook_name.localizedCaseInsensitiveContains(filterName)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                FilterField(placeholder: "Filter by runbook name", text: $filterName)
            }
            .padding()

            if filteredRecords.isEmpty {
                ContentUnavailableView(
                    "No Run History",
                    systemImage: "clock",
                    description: Text("Run a runbook to see its history here.")
                )
            } else {
                // ScrollView + LazyVStack rather than List: macOS List caches
                // row heights and won't re-measure when an expanded inner log
                // collapses, leaving a phantom gap where the log used to be.
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredRecords) { record in
                            HistoryRowView(record: record)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                            Divider()
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem {
                ContextualHelpButton(topic: .history)
            }
        }
        .onAppear { store.loadAll() }
    }
}

struct HistoryRowView: View {
    @Environment(RunbookStore.self) private var store
    let record: HistoryRecord
    @State private var expanded = false
    @State private var showLog = false

    private var logFile: URL? {
        StepLogExtractor.findLogURL(for: record)
    }

    /// Position of this record in the runbook's history sorted newest-first.
    /// Used as a fallback when log markers don't carry a timestamp.
    private var runIndexFromEnd: Int {
        store.history(for: record.runbook_name)
            .firstIndex(where: { $0.id == record.id }) ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    expanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .frame(width: 12)
                    Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(record.success ? .green : .red)
                    VStack(alignment: .leading) {
                        Text(record.runbook_name)
                            .fontWeight(.medium)
                        Text(record.formattedDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if logFile != nil {
                        Image(systemName: "doc.text")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Text("\(record.step_count) steps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(record.duration)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(record.steps) { step in
                        StepHistoryRow(
                            step: step,
                            record: record,
                            logFile: logFile,
                            runIndexFromEnd: runIndexFromEnd
                        )
                    }

                    if let log = logFile {
                        Divider().padding(.top, 4)
                        Button {
                            showLog = true
                        } label: {
                            Label("View Full Log", systemImage: "doc.text")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .sheet(isPresented: $showLog) {
                            LogViewerSheet(url: log, matchDate: record.startedDate)
                        }
                    }
                }
                .padding(.leading, 24)
                .padding(.vertical, 4)
            }
        }
    }

    private func statusIcon(_ status: String) -> String {
        switch status {
        case "success": "checkmark.circle.fill"
        case "failed": "xmark.circle.fill"
        case "skipped": "minus.circle"
        default: "circle"
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "success": .green
        case "failed": .red
        case "skipped": .gray
        default: .secondary
        }
    }
}

/// One step row inside the expanded HistoryRowView. Status + duration are
/// always visible; click the chevron to lazy-load the per-step log slice
/// for THIS run (not the most recent — see scopeToRun in StepLogExtractor).
struct StepHistoryRow: View {
    let step: StepRecord
    let record: HistoryRecord
    let logFile: URL?
    let runIndexFromEnd: Int

    @State private var expanded = false
    @State private var stepLogText: String?
    @State private var loadState: LoadState = .idle
    @State private var justCopied = false

    private enum LoadState { case idle, loading, loaded }

    private var statusIcon: String {
        switch step.status {
        case "success": return "checkmark.circle.fill"
        case "failed": return "xmark.circle.fill"
        case "skipped": return "minus.circle"
        default: return "circle"
        }
    }

    private var statusTint: Color {
        switch step.status {
        case "success": return .green
        case "failed": return .red
        case "skipped": return .gray
        default: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                if logFile != nil { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .opacity(logFile != nil ? 1 : 0)
                        .frame(width: 10)
                    Image(systemName: statusIcon)
                        .foregroundStyle(statusTint)
                        .frame(width: 16)
                    Text(step.name)
                        .font(.caption)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(step.duration)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let error = step.error, !error.isEmpty {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.leading, 32)
                    .textSelection(.enabled)
            }

            if expanded {
                stepLogBody
                    .padding(.leading, 32)
                    .padding(.trailing, 4)
                    .padding(.top, 2)
            }
        }
        .task(id: expandedKey) {
            guard expanded, loadState == .idle, let url = logFile else { return }
            loadState = .loading
            let stepName = step.name
            let recordCopy = record
            let idx = runIndexFromEnd
            let extracted: String? = await Task.detached(priority: .userInitiated) {
                StepLogExtractor.extractStepLines(
                    logURL: url,
                    stepName: stepName,
                    record: recordCopy,
                    runIndexFromEnd: idx
                )
            }.value
            stepLogText = extracted
            loadState = .loaded
        }
    }

    /// Combines `expanded` with the step name so .task re-fires when the
    /// user collapses then re-expands a different step in the same row.
    private var expandedKey: String { "\(expanded ? "1" : "0")|\(step.name)" }

    @ViewBuilder
    private var stepLogBody: some View {
        switch loadState {
        case .idle, .loading:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Loading log…")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        case .loaded:
            if let text = stepLogText, !text.isEmpty {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()), id: \.offset) { _, line in
                            let str = String(line)
                            let highlight = OutputHighlighter.color(for: str)
                            let attr = OutputHighlighter.attributedLine(for: str, baseColor: highlight.color)
                            let hasLink = attr.runs.contains { $0.link != nil }
                            Text(attr)
                                .font(.system(size: 11, design: .monospaced))
                                .fontWeight(highlight.bold ? .bold : .regular)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .pointerStyle(hasLink ? .link : nil)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 240)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.08))
                )
                .overlay(alignment: .topTrailing) {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                        withAnimation(.easeInOut(duration: 0.15)) {
                            justCopied = true
                        }
                        Task {
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            withAnimation(.easeInOut(duration: 0.15)) {
                                justCopied = false
                            }
                        }
                    } label: {
                        Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                            .font(.caption2)
                            .foregroundStyle(justCopied ? Color.green : .secondary)
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.background.opacity(0.6))
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                    .help(justCopied ? "Copied" : "Copy step log to clipboard")
                }
            } else {
                Text("No log output captured for this step in this run.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct LogSection: Identifiable, Hashable {
    let id: Int
    let title: String
    let content: String
    let timestamp: Date?
}

struct LogViewerSheet: View {
    let url: URL
    var matchDate: Date?
    @Environment(\.dismiss) private var dismiss
    @State private var rawContent = ""
    @State private var sections: [LogSection] = []
    @State private var selectedSection: Int = 0

    private var currentContent: String {
        guard sections.indices.contains(selectedSection) else { return rawContent }
        return sections[selectedSection].content
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if sections.count > 1 {
                    Picker("Run", selection: $selectedSection) {
                        ForEach(sections) { section in
                            Text(section.title).tag(section.id)
                        }
                    }
                    .frame(maxWidth: 300)
                } else {
                    Text(url.lastPathComponent)
                        .font(.headline)
                }
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(currentContent, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(currentContent.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                        let highlight = OutputHighlighter.color(for: line)
                        let attr = OutputHighlighter.attributedLine(for: line, baseColor: highlight.color)
                        let hasLink = attr.runs.contains { $0.link != nil }
                        Text(attr)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(highlight.bold ? .bold : .regular)
                            .textSelection(.enabled)
                            .pointerStyle(hasLink ? .link : nil)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .background(.black.opacity(0.03))

            Divider()

            HStack {
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                if sections.count > 1 {
                    Text("\(selectedSection + 1) of \(sections.count) runs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            loadContent()
            parseSections()
            selectMatchingSection()
        }
    }

    private func loadContent() {
        if url.pathExtension == "gz" {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/gunzip")
            task.arguments = ["-c", url.path]
            let pipe = Pipe()
            task.standardOutput = pipe
            try? task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            rawContent = String(data: data, encoding: .utf8) ?? "Could not decompress log file."
        } else {
            rawContent = (try? String(contentsOf: url, encoding: .utf8)) ?? "Could not read log file."
        }
    }

    private func parseSections() {
        let separator = "--- run: "
        let parts = rawContent.components(separatedBy: "\n" + separator)

        if parts.count <= 1 {
            // No separators — single run, show as-is
            sections = [LogSection(id: 0, title: url.lastPathComponent, content: rawContent, timestamp: nil)]
            return
        }

        var result: [LogSection] = []
        for (i, part) in parts.enumerated() {
            if i == 0 {
                // Content before first separator (may be empty)
                let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    result.append(LogSection(id: i, title: "Header", content: trimmed, timestamp: nil))
                }
                continue
            }
            // Part starts with "2026-04-06T18:06:00 ---\n..."
            let lines = part.components(separatedBy: "\n")
            let headerLine = lines.first ?? ""
            let timestampStr = headerLine.replacingOccurrences(of: " ---", with: "").trimmingCharacters(in: .whitespaces)

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            let date = formatter.date(from: timestampStr)

            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d, yyyy 'at' h:mm:ss a"
            let title = date.map { displayFormatter.string(from: $0) } ?? timestampStr

            let body = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            result.append(LogSection(id: result.count, title: title, content: body, timestamp: date))
        }

        sections = result
    }

    private func selectMatchingSection() {
        guard let matchDate, sections.count > 1 else { return }
        // Find section with closest timestamp within 60 seconds
        if let best = sections.enumerated().min(by: { a, b in
            guard let aDate = a.element.timestamp, let bDate = b.element.timestamp else { return false }
            return abs(aDate.timeIntervalSince(matchDate)) < abs(bDate.timeIntervalSince(matchDate))
        }), let ts = best.element.timestamp, abs(ts.timeIntervalSince(matchDate)) < 120 {
            selectedSection = best.offset
        }
    }
}
