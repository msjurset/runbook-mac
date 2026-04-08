import SwiftUI

struct CLISetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var installer = CLIInstaller()

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Runbook CLI Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("The Runbook Mac app requires the **runbook** command-line tool to function. It will be installed to `~/.local/bin/runbook`.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)

            if installer.isDownloading {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Downloading and installing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if installer.isInstalled {
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
            } else {
                Button {
                    Task { await installer.install() }
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
                    .frame(maxWidth: 400)

                Text("You can also install manually:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("brew install msjurset/tap/runbook")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
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
            .frame(maxWidth: 400)
        }
        .padding(30)
        .frame(width: 480)
        .onAppear {
            installer.checkInstalledVersion()
        }
    }
}
