import SwiftUI

struct PullView: View {
    @Environment(RunbookStore.self) private var store
    @State private var repos: [RepoEntry] = []
    @State private var repoURL = ""
    @State private var isLoading = false
    @State private var isPulling = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    struct RepoEntry: Identifiable {
        var id: String { name }
        var name: String
        var runbookCount: Int
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Repositories")
                    .font(.headline)
                Spacer()
                Button("Refresh All", systemImage: "arrow.clockwise") {
                    refreshAll()
                }
                .disabled(isLoading)
            }
            .padding()

            Divider()

            // Pull form
            VStack(alignment: .leading, spacing: 8) {
                Text("Pull Runbooks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    FilterField(placeholder: "Git repo URL or single YAML file URL", text: $repoURL)
                    Button {
                        pullRepo()
                    } label: {
                        if isPulling {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Pull", systemImage: "arrow.down.circle")
                        }
                    }
                    .disabled(repoURL.isEmpty || isPulling)
                }
                Text("Examples: github.com/user/runbooks  or  https://example.com/deploy.yaml")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding()

            if let err = errorMessage {
                ErrorBanner(message: err) { errorMessage = nil }
            }

            if let msg = successMessage {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.green)
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.green)
                    Spacer()
                    Button("Dismiss") { successMessage = nil }
                        .font(.caption)
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }

            Divider()

            // Repo list
            if repos.isEmpty && !isLoading {
                ContentUnavailableView(
                    "No Repositories",
                    systemImage: "arrow.down.circle",
                    description: Text("Pull a git repo or YAML URL to import shared runbooks.")
                )
            } else {
                List {
                    ForEach(repos) { repo in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "folder.badge.gearshape")
                                    .foregroundStyle(.teal)
                                    .frame(width: 20)
                                Text(repo.name)
                                    .font(.headline)
                                Spacer()
                                Button {
                                    updateRepo(name: repo.name)
                                } label: {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.secondary)
                                .help("Update to latest")
                                Button(role: .destructive) {
                                    removeRepo(name: repo.name)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.secondary)
                                .help("Remove repository")
                            }

                            HStack(spacing: 12) {
                                Label("\(repo.runbookCount) runbook\(repo.runbookCount == 1 ? "" : "s")", systemImage: "doc.text")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .navigationTitle("Repositories")
        .toolbar {
            ToolbarItem {
                ContextualHelpButton(topic: .sharing)
            }
        }
        .onAppear { loadRepoList() }
    }

    private func loadRepoList() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let result = try await RunbookCLI.shared.pullList()
                await MainActor.run {
                    repos = parseRepoList(result)
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

    private func parseRepoList(_ text: String) -> [RepoEntry] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard lines.count > 1 else { return [] }

        var entries: [RepoEntry] = []
        for line in lines.dropFirst() { // skip header
            let parts = line.split(separator: "\t").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2 {
                let name = parts[0]
                let count = Int(parts[1]) ?? 0
                entries.append(RepoEntry(name: name, runbookCount: count))
            } else {
                // Try splitting on multiple spaces
                let spaceParts = line.components(separatedBy: "  ").filter { !$0.isEmpty }.map { $0.trimmingCharacters(in: .whitespaces) }
                if spaceParts.count >= 2 {
                    entries.append(RepoEntry(name: spaceParts[0], runbookCount: Int(spaceParts[1]) ?? 0))
                }
            }
        }
        return entries
    }

    private func pullRepo() {
        isPulling = true
        errorMessage = nil
        successMessage = nil
        Task {
            do {
                let result = try await RunbookCLI.shared.pull(url: repoURL)
                await MainActor.run {
                    repoURL = ""
                    isPulling = false
                    successMessage = result
                }
                loadRepoList()
                store.loadAll()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isPulling = false
                }
            }
        }
    }

    private func updateRepo(name: String) {
        errorMessage = nil
        successMessage = nil
        Task {
            do {
                let result = try await RunbookCLI.shared.pull(url: name)
                await MainActor.run {
                    successMessage = result
                }
                loadRepoList()
                store.loadAll()
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    private func removeRepo(name: String) {
        errorMessage = nil
        successMessage = nil
        Task {
            do {
                _ = try await RunbookCLI.shared.pullRemove(name: name)
                loadRepoList()
                store.loadAll()
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    private func refreshAll() {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        Task {
            var updated = 0
            for repo in repos {
                do {
                    _ = try await RunbookCLI.shared.pull(url: repo.name)
                    updated += 1
                } catch {
                    // continue with next
                }
            }
            await MainActor.run {
                if updated > 0 {
                    successMessage = "Updated \(updated) repository\(updated == 1 ? "" : "ies")"
                }
                isLoading = false
            }
            loadRepoList()
            store.loadAll()
        }
    }
}
