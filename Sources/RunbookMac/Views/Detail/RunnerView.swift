import SwiftUI
import AppKit

struct RunnerView: View {
    let runbook: Runbook
    @State var dryRun = false
    @Environment(\.dismiss) private var dismiss
    @State private var output: [String] = []
    @State private var isRunning = false
    @State private var success: Bool?
    @State private var vars: [String: String] = [:]
    @State private var runTask: Task<Void, Never>?
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
            // Header
            HStack {
                VStack(alignment: .leading) {
                    HStack(spacing: 8) {
                        Text("\(dryRun ? "Dry Run" : "Run"): \(runbook.name)")
                            .font(.headline)
                        if dryRun {
                            Text("preview")
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                    if let desc = runbook.description {
                        Text(desc).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                statusBadge
            }
            .padding()

            Divider()

            // Variable inputs
            if let defs = runbook.variables, !defs.isEmpty {
                variableInputs(defs)
                Divider()
            }

            // Output toolbar
            if !output.isEmpty {
                outputToolbar
                Divider()
            }

            // Search bar
            if showSearch {
                searchBar
                Divider()
            }

            // Output
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

            Divider()

            // Controls
            HStack {
                if isDone {
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                    Spacer()
                    Toggle("Dry Run", isOn: $dryRun)
                        .toggleStyle(.checkbox)
                    Button(dryRun ? "Run Again" : "Run") {
                        success = nil
                        startRun()
                    }
                } else if isRunning {
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 4)
                    Button("Stop", role: .destructive) { stopRun() }
                        .keyboardShortcut(".", modifiers: .command)
                } else {
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Toggle("Dry Run", isOn: $dryRun)
                        .toggleStyle(.checkbox)
                    Button("Run") { startRun() }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            for v in runbook.variables ?? [] {
                if let def = v.default, !def.hasPrefix("op://") {
                    vars[v.name] = def
                }
            }
        }
    }

    // MARK: - Output Toolbar

    private var outputToolbar: some View {
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
            TextField("Search output", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .focused($searchFocused)
                .onSubmit { nextMatch() }

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

    @ViewBuilder
    private func outputLine(idx: Int, line: String) -> some View {
        let isMatch = !searchText.isEmpty && line.localizedCaseInsensitiveContains(searchText)
        let isCurrentMatch = isMatch && matchingLines.indices.contains(currentMatch) && matchingLines[currentMatch] == idx

        Text(line)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .padding(.horizontal, isMatch ? 4 : 0)
            .padding(.vertical, isMatch ? 1 : 0)
            .background(
                isCurrentMatch ? Color.yellow.opacity(0.3) :
                isMatch ? Color.yellow.opacity(0.1) : .clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 2))
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
        let logsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".runbook/logs")
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

        let timestamp = ISO8601DateFormatter.string(
            from: Date(),
            timeZone: .current,
            formatOptions: [.withFullDate, .withTime, .withDashSeparatorInDate]
        ).replacingOccurrences(of: ":", with: "-")

        let panel = NSSavePanel()
        panel.directoryURL = logsDir
        panel.nameFieldStringValue = "\(runbook.name)-\(timestamp).log"
        panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try outputText.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                output.append("Save failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - State

    private var isDone: Bool { success != nil && !isRunning }

    private func variableInputs(_ defs: [VariableDef]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Variables")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(defs) { v in
                HStack {
                    Text(v.name)
                        .font(.body.monospaced())
                        .frame(width: 120, alignment: .trailing)
                    if isDone {
                        Text(vars[v.name] ?? v.default ?? "")
                            .font(.body.monospaced())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        TextField(v.default ?? "", text: binding(for: v.name))
                            .textFieldStyle(.roundedBorder)
                            .disabled(isRunning)
                        if v.required == true {
                            Text("required")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { vars[key] ?? "" },
            set: { vars[key] = $0 }
        )
    }

    @ViewBuilder
    private var statusBadge: some View {
        if let success {
            Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(success ? .green : .red)
                .font(.title2)
        }
    }

    // MARK: - Execution

    private func startRun() {
        output = []
        success = nil
        isRunning = true
        showSearch = false
        searchText = ""

        runTask = Task {
            do {
                let result = try await RunbookCLI.shared.run(
                    name: runbook.name,
                    vars: vars,
                    dryRun: dryRun
                ) { line in
                    Task { @MainActor in
                        output.append(line)
                    }
                }
                await MainActor.run {
                    success = result
                    isRunning = false
                }
            } catch is CancellationError {
                await MainActor.run {
                    output.append("Stopped.")
                    success = false
                    isRunning = false
                }
            } catch {
                await MainActor.run {
                    output.append("Error: \(error.localizedDescription)")
                    success = false
                    isRunning = false
                }
            }
        }
    }

    private func stopRun() {
        runTask?.cancel()
    }
}
