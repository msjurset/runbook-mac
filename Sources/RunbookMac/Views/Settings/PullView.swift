import SwiftUI

struct PullView: View {
    @Environment(RunbookStore.self) private var store
    @State private var output = ""
    @State private var repoURL = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Repositories")
                    .font(.headline)
                Spacer()
                Button("Refresh", systemImage: "arrow.clockwise") {
                    loadRepoList()
                }
            }
            .padding()

            Divider()

            // Pull form
            HStack {
                TextField("Git repo URL or file URL", text: $repoURL)
                    .textFieldStyle(.roundedBorder)
                Button("Pull") { pullRepo() }
                    .disabled(repoURL.isEmpty || isLoading)
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding()

            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Divider()

            if output.isEmpty && !isLoading {
                ContentUnavailableView(
                    "No Repositories",
                    systemImage: "arrow.down.circle",
                    description: Text("Pull a git repo to import shared runbooks.")
                )
            } else {
                ScrollView {
                    Text(output)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
        }
        .navigationTitle("Repositories")
        .onAppear { loadRepoList() }
    }

    private func loadRepoList() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let result = try await RunbookCLI.shared.pullList()
                await MainActor.run {
                    output = result
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func pullRepo() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                _ = try await RunbookCLI.shared.pull(url: repoURL)
                await MainActor.run {
                    repoURL = ""
                    isLoading = false
                }
                loadRepoList()
                store.loadAll()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}
