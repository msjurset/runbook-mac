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
                List(filteredRecords) { record in
                    HistoryRowView(record: record)
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
    let record: HistoryRecord
    @State private var expanded = false
    @State private var showLog = false

    private var logFile: URL? {
        LogIndex.logPath(for: record)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(record.steps) { step in
                    HStack {
                        Image(systemName: statusIcon(step.status))
                            .foregroundStyle(statusColor(step.status))
                            .frame(width: 16)
                        Text(step.name)
                            .font(.caption)
                        Spacer()
                        Text(step.duration)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    if let error = step.error, !error.isEmpty {
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .padding(.leading, 20)
                    }
                }

                if let log = logFile {
                    Divider()
                    Button {
                        showLog = true
                    } label: {
                        Label("View Saved Log", systemImage: "doc.text")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .sheet(isPresented: $showLog) {
                        LogViewerSheet(url: log, matchDate: record.startedDate)
                    }
                }
            }
            .padding(.vertical, 4)
        } label: {
            HStack {
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
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(highlight.bold ? .bold : .regular)
                            .foregroundStyle(highlight.color)
                            .textSelection(.enabled)
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
