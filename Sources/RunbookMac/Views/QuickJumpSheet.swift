import SwiftUI

struct QuickJumpSheet: View {
    @Environment(RunbookStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedRunbook: Runbook?
    @Binding var sidebarSelection: SidebarItem?
    @State private var query = ""
    @State private var highlightedIndex = 0
    @FocusState private var isFocused: Bool

    private var results: [Runbook] {
        if query.isEmpty {
            return store.runbooks
        }
        return store.runbooks.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Go to runbook...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isFocused)
                    .onSubmit { selectHighlighted() }
                    .textContentType(.none)
                    .autocorrectionDisabled()
            }
            .padding()

            Divider()

            if results.isEmpty {
                Text("No matching runbooks")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(Array(results.prefix(15).enumerated()), id: \.element.id) { idx, book in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(book.name)
                                        .fontWeight(.medium)
                                    if let desc = book.description, !desc.isEmpty {
                                        Text(desc)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Text("\(book.steps.count) steps")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 2)
                            .listRowBackground(idx == highlightedIndex ? Color.accentColor.opacity(0.2) : nil)
                            .id(idx)
                            .onTapGesture { select(book) }
                        }
                    }
                    .listStyle(.plain)
                    .onChange(of: highlightedIndex) {
                        proxy.scrollTo(highlightedIndex, anchor: .center)
                    }
                }
            }
        }
        .frame(width: 450, height: 350)
        .onAppear {
            isFocused = true
        }
        .onChange(of: query) {
            highlightedIndex = 0
        }
        .onKeyPress(.upArrow) {
            if highlightedIndex > 0 { highlightedIndex -= 1 }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if highlightedIndex < min(results.count, 15) - 1 { highlightedIndex += 1 }
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }

    private func selectHighlighted() {
        let capped = results.prefix(15)
        guard capped.indices.contains(highlightedIndex) else { return }
        select(capped[highlightedIndex])
    }

    private func select(_ book: Runbook) {
        sidebarSelection = .runbooks
        selectedRunbook = book
        dismiss()
    }
}
