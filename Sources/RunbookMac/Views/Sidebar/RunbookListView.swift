import SwiftUI

struct RunbookListView: View {
    @Environment(RunbookStore.self) private var store
    @Environment(RunSessionStore.self) private var runSessions
    @Binding var selectedRunbook: Runbook?
    @State private var searchText = ""
    @State private var showTemplates = true
    @State private var templateToCreate: Runbook?
    @State private var runbookToDuplicate: Runbook?
    /// Pre-run dialog target. The accompanying `pendingRunDryRun` seeds the
    /// sheet's Dry Run checkbox so a right-click on Dry Run opens the sheet
    /// with that toggle on. On confirm the sheet dispatches into the
    /// RunSessionStore so output streams to the docked ConsoleTray rather
    /// than the old all-in-one RunnerView modal.
    @State private var runbookToConfirmRun: Runbook?
    @State private var pendingRunDryRun = false
    @State private var runbookToSchedule: Runbook?
    @State private var errorMessage: String?
    /// New-runbook sheet trigger. Owned here so the "+" button at the
    /// list's top-right opens it; previously this state lived in
    /// ContentView and was driven by a button in the sidebar's bottom
    /// strip, which was an awkward place for "create item in this list".
    @State private var showNewRunbook = false

    private var filteredRunbooks: [Runbook] {
        let base = searchText.isEmpty ? store.runbooks : store.runbooks.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
        let pinned = store.pinnedNames
        return base.sorted { a, b in
            let aPinned = pinned.contains(a.name)
            let bPinned = pinned.contains(b.name)
            if aPinned != bPinned { return aPinned }
            return a.name < b.name
        }
    }

    private var filteredTemplates: [Runbook] {
        if searchText.isEmpty {
            return store.templates
        }
        return store.templates.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                FilterField(placeholder: "Filter runbooks", text: $searchText)
                Button(action: { showNewRunbook = true }) {
                    Image(systemName: "plus")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("New Runbook")
                .accessibilityIdentifier("toolbar.newRunbook")
            }
            .padding(8)

            List(selection: $selectedRunbook) {
                Section("Runbooks") {
                    ForEach(filteredRunbooks) { book in
                        runbookRow(book)
                    }
                }

                if !filteredTemplates.isEmpty {
                    Section(isExpanded: $showTemplates) {
                        ForEach(filteredTemplates) { book in
                            templateRow(book)
                        }
                    } header: {
                        Label("Templates", systemImage: "doc.on.doc")
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .sheet(item: $templateToCreate) { tmpl in
                CreateFromTemplateSheet(template: tmpl)
            }
            .sheet(item: $runbookToDuplicate) { book in
                CreateFromTemplateSheet(template: book, isDuplicate: true)
            }
            .sheet(item: $runbookToConfirmRun) { book in
                RunConfirmSheet(runbook: book, initialDryRun: pendingRunDryRun) { vars, dryRun in
                    _ = runSessions.start(runbook: book, vars: vars, dryRun: dryRun)
                }
            }
            .sheet(item: $runbookToSchedule) { book in
                ScheduleRunbookSheet(runbookName: book.name)
            }
            .sheet(isPresented: $showNewRunbook) {
                NewRunbookSheet { name, content in
                    try store.saveRaw(content, to: "\(name).yaml")
                    store.loadAll()
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityIdentifier("runbookList")
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func isFromRepo(_ book: Runbook) -> Bool {
        guard let path = book.filePath else { return false }
        let booksPath = AppSettings.booksURL.path
        let relative = String(path.dropFirst(booksPath.count + 1))
        return relative.contains("/")
    }

    private func repoName(_ book: Runbook) -> String? {
        guard let path = book.filePath else { return nil }
        let booksPath = AppSettings.booksURL.path
        let relative = String(path.dropFirst(booksPath.count + 1))
        return relative.components(separatedBy: "/").first
    }

    private func runbookRow(_ book: Runbook) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if store.isPinned(book) {
                    Button {
                        store.togglePin(book)
                    } label: {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue.opacity(0.7))
                    }
                    .buttonStyle(.borderless)
                    .help("Unpin")
                }
                Text(book.name)
                    .fontWeight(.medium)
                if isFromRepo(book) {
                    Image(systemName: "arrow.down.circle")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .help("From repo: \(repoName(book) ?? "unknown")\n\(book.filePath ?? "")")
                }
            }
            if let desc = book.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                Label("\(book.steps.count) steps", systemImage: "list.number")
                if let vars = book.variables, !vars.isEmpty {
                    Label("\(vars.count) vars", systemImage: "textformat.abc")
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .tag(book)
        .contextMenu {
            Button("Run", systemImage: "play.fill") {
                pendingRunDryRun = false
                runbookToConfirmRun = book
            }
            Button("Dry Run", systemImage: "forward.end") {
                pendingRunDryRun = true
                runbookToConfirmRun = book
            }
            Button("Schedule", systemImage: "calendar.badge.clock") {
                runbookToSchedule = book
            }
            Divider()
            Button(store.isPinned(book) ? "Unpin" : "Pin",
                   systemImage: store.isPinned(book) ? "pin.slash" : "pin") {
                store.togglePin(book)
            }
            Button("Duplicate", systemImage: "plus.doc.on.doc") {
                runbookToDuplicate = book
            }
            Divider()
            Button("Delete", role: .destructive) {
                deleteRunbook(book)
            }
        }
    }

    private func templateRow(_ book: Runbook) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(book.name)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Text("template")
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.orange.opacity(0.15))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }
            if let desc = book.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                Label("\(book.steps.count) steps", systemImage: "list.number")
                if let vars = book.variables, !vars.isEmpty {
                    Label("\(vars.count) vars", systemImage: "textformat.abc")
                }
            }
            .font(.caption2)
            .foregroundStyle(.quaternary)
        }
        .padding(.vertical, 2)
        .tag(book)
        .contextMenu {
            Button("New from Template", systemImage: "plus.doc.on.doc") {
                templateToCreate = book
            }
        }
    }

    private func deleteRunbook(_ book: Runbook) {
        do {
            try store.delete(book)
            store.loadAll()
            if selectedRunbook == book {
                selectedRunbook = nil
            }
        } catch {
            errorMessage = "Could not delete \"\(book.name)\": \(error.localizedDescription)"
        }
    }
}
