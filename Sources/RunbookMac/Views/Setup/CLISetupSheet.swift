import SwiftUI

struct CLISetupSheet: View {
    @Environment(RunbookStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var installer = CLIInstaller()
    @State private var installDir = CLIInstaller.defaultInstallDir
    @State private var pathWarning: String?
    @State private var repoPulled = false
    @State private var repoPulling = false
    @State private var repoError: String?

    private var isDefaultDir: Bool {
        installDir == CLIInstaller.defaultInstallDir
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Runbook Setup")
                .font(.title2)
                .fontWeight(.semibold)

            // Step 1: CLI Install
            GroupBox {
                HStack(spacing: 12) {
                    stepIndicator(done: installer.isInstalled, number: 1)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Install CLI")
                            .fontWeight(.medium)
                        Text("The runbook command-line tool is required.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    if installer.isDownloading {
                        ProgressView().controlSize(.small)
                    } else if installer.isInstalled {
                        if let version = installer.installedVersion {
                            Text("v\(version)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Install") {
                            Task { await installer.install(to: installDir) }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }

                if !installer.isInstalled && !installer.isDownloading {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Install directory", text: $installDir)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.caption, design: .monospaced))
                            Button("Browse...") { browseDirectory() }
                                .font(.caption)
                        }

                        if let warning = pathWarning {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                                Text(warning)
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding(.top, 4)
                    .onChange(of: installDir) { checkPATH() }
                    .onAppear { checkPATH() }
                }

                if let error = installer.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text("Manual install: `brew install msjurset/tap/runbook`")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            // Step 2: Pull shared runbooks
            GroupBox {
                HStack(spacing: 12) {
                    stepIndicator(done: repoPulled, number: 2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Get Templates & Runbooks")
                            .fontWeight(.medium)
                        Text("Pull shared templates and system runbooks from GitHub.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    if repoPulling {
                        ProgressView().controlSize(.small)
                    } else if repoPulled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if installer.isInstalled {
                        Button("Pull") { pullRepo() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    } else {
                        Text("Install CLI first")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                if repoPulled {
                    Text("Templates and system runbooks are now available in the sidebar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = repoError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            HStack {
                if !installer.isInstalled {
                    Button("Skip for Now") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if installer.isInstalled {
                    Button("Done") {
                        store.loadAll()
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(30)
        .frame(width: 520)
        .onAppear {
            installer.checkInstalledVersion()
            // Check if repo already pulled
            let repoDir = URL(fileURLWithPath: AppSettings.runbookDir).appendingPathComponent("runbooks")
            repoPulled = FileManager.default.fileExists(atPath: repoDir.appendingPathComponent(".git").path)
        }
    }

    private func pullRepo() {
        repoPulling = true
        repoError = nil
        Task {
            do {
                _ = try await RunbookCLI.shared.pull(url: "github.com/msjurset/runbooks")
                await MainActor.run {
                    repoPulled = true
                    repoPulling = false
                    store.loadAll()
                }
            } catch {
                await MainActor.run {
                    repoError = error.localizedDescription
                    repoPulling = false
                }
            }
        }
    }

    @ViewBuilder
    private func stepIndicator(done: Bool, number: Int) -> some View {
        if done {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
        } else {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(.blue))
        }
    }

    private func checkPATH() {
        let dir = (installDir as NSString).expandingTildeInPath
        if CLIInstaller.isInPATH(dir) {
            pathWarning = nil
        } else if isDefaultDir {
            pathWarning = "~/.local/bin/ is the XDG standard for user-local binaries but is not currently in your $PATH. The Mac app will work fine, but to use the CLI from your terminal, add it to your shell profile:\n\nexport PATH=\"$HOME/.local/bin:$PATH\""
        } else {
            pathWarning = "\(installDir) is not in your $PATH. The Mac app will still work, but terminal use requires adding it to your shell profile."
        }
    }

    private func browseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: (installDir as NSString).expandingTildeInPath)
        panel.prompt = "Choose"
        panel.message = "Select a directory for the runbook CLI binary"
        if panel.runModal() == .OK, let url = panel.url {
            installDir = url.path
        }
    }
}
