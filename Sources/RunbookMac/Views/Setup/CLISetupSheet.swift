import SwiftUI

struct CLISetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var installer = CLIInstaller()
    @State private var installDir = CLIInstaller.defaultInstallDir
    @State private var pathWarning: String?

    private var isDefaultDir: Bool {
        installDir == CLIInstaller.defaultInstallDir
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Runbook CLI Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("The Runbook Mac app requires the **runbook** command-line tool to function.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 440)

            if installer.isDownloading {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Downloading and installing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if installer.isInstalled {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title3)
                        VStack(alignment: .leading) {
                            Text("CLI Installed")
                                .fontWeight(.medium)
                            if let version = installer.installedVersion {
                                Text("Version \(version)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if let path = CLIInstaller.resolvedPath {
                        Text(path)
                            .font(.caption.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                }
            } else {
                // Install path picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Install Location")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("Install directory", text: $installDir)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        Button("Browse...") { browseDirectory() }
                    }
                    .frame(maxWidth: 440)

                    // PATH warning
                    if let warning = pathWarning {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text(warning)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        .frame(maxWidth: 440, alignment: .leading)
                    }
                }
                .onChange(of: installDir) {
                    checkPATH()
                }
                .onAppear {
                    checkPATH()
                }

                Button {
                    Task { await installer.install(to: installDir) }
                } label: {
                    Label("Install Runbook CLI", systemImage: "arrow.down.circle")
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            }

            if let error = installer.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: 440)

                VStack(spacing: 4) {
                    Text("You can also install manually:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("brew install msjurset/tap/runbook")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            HStack {
                if !installer.isInstalled && !installer.isDownloading {
                    Button("Skip for Now") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if installer.isInstalled {
                    Button("Continue") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .frame(maxWidth: 440)
        }
        .padding(30)
        .frame(width: 520)
        .onAppear {
            installer.checkInstalledVersion()
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
