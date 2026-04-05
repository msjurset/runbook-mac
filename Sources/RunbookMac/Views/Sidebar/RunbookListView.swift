import SwiftUI

struct RunbookListView: View {
    @Environment(RunbookStore.self) private var store
    @Binding var selectedRunbook: Runbook?
    @State private var searchText = ""
    @State private var showTemplates = true
    @State private var templateToCreate: Runbook?
    @State private var runbookToDuplicate: Runbook?
    @State private var runbookToRun: Runbook?
    @State private var runbookToDryRun: Runbook?

    private var filteredRunbooks: [Runbook] {
        let base = searchText.isEmpty ? store.runbooks : store.runbooks.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
        return base.sorted { a, b in
            let aPinned = store.isPinned(a)
            let bPinned = store.isPinned(b)
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
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                FilterField(placeholder: "Filter runbooks", text: $searchText)
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
            .sheet(item: $runbookToRun) { book in
                RunnerView(runbook: book)
            }
            .sheet(item: $runbookToDryRun) { book in
                RunnerView(runbook: book, dryRun: true)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityIdentifier("runbookList")
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
                runbookToRun = book
            }
            Button("Dry Run", systemImage: "forward.end") {
                runbookToDryRun = book
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
        try? store.delete(book)
        store.loadAll()
        if selectedRunbook == book {
            selectedRunbook = nil
        }
    }
}
