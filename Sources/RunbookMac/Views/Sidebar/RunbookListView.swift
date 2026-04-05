import SwiftUI

struct RunbookListView: View {
    @Environment(RunbookStore.self) private var store
    @Binding var selectedRunbook: Runbook?
    @State private var searchText = ""

    private var filteredRunbooks: [Runbook] {
        if searchText.isEmpty {
            return store.runbooks
        }
        return store.runbooks.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter runbooks", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(8)

            List(selection: $selectedRunbook) {
                ForEach(filteredRunbooks) { book in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(book.name)
                            .fontWeight(.medium)
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
                        Button("Delete", role: .destructive) {
                            deleteRunbook(book)
                        }
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityIdentifier("runbookList")
    }

    private func deleteRunbook(_ book: Runbook) {
        try? store.delete(book)
        store.loadAll()
        if selectedRunbook == book {
            selectedRunbook = nil
        }
    }
}
