import SwiftUI

struct CLIUpdateBanner: View {
    @State private var installer = CLIInstaller()
    @State private var dismissed = false

    var body: some View {
        if installer.isUpdateAvailable && !dismissed && !installer.isDownloading {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.blue)
                Text("Runbook CLI v\(installer.latestVersion ?? "") available")
                    .font(.caption)
                Spacer()
                Button("Update") {
                    Task { await installer.install() }
                }
                .font(.caption)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                Button {
                    dismissed = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(.blue.opacity(0.08))
        } else if installer.isDownloading {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Updating CLI...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(.blue.opacity(0.08))
        }
    }
}
