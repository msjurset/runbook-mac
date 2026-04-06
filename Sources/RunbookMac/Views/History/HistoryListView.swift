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
                        LogViewerSheet(url: log)
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

struct LogViewerSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var content = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(url.lastPathComponent)
                    .font(.headline)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(content, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            ScrollView {
                Text(content)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(.black.opacity(0.03))

            Divider()

            HStack {
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            if url.pathExtension == "gz" {
                // Decompress gzip
                if let data = try? Data(contentsOf: url),
                   let decompressed = try? (data as NSData).decompressed(using: .zlib) as Data,
                   let text = String(data: decompressed, encoding: .utf8) {
                    content = text
                } else {
                    // Try NSData gzip decompression via shell
                    let task = Process()
                    task.executableURL = URL(fileURLWithPath: "/usr/bin/gunzip")
                    task.arguments = ["-c", url.path]
                    let pipe = Pipe()
                    task.standardOutput = pipe
                    try? task.run()
                    task.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    content = String(data: data, encoding: .utf8) ?? "Could not decompress log file."
                }
            } else {
                content = (try? String(contentsOf: url, encoding: .utf8)) ?? "Could not read log file."
            }
        }
    }
}
