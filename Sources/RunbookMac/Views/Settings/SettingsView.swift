import SwiftUI

struct SettingsView: View {
    @State private var runbookDir = AppSettings.runbookDir
    @State private var editorFontSize = AppSettings.editorFontSize
    @State private var installer = CLIInstaller()

    var body: some View {
        Form {
            Section("Runbook CLI") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        if let version = installer.installedVersion {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Installed: v\(version)")
                            }
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("Not installed")
                            }
                        }
                        if let path = CLIInstaller.resolvedPath {
                            Text(path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if installer.isDownloading {
                        ProgressView()
                            .controlSize(.small)
                    } else if !installer.isInstalled {
                        Button("Install") {
                            Task { await installer.install() }
                        }
                    } else {
                        Button("Check for Updates") {
                            installer.checkInstalledVersion()
                            Task {
                                await installer.checkLatestVersion()
                            }
                        }
                    }
                }
                if let latest = installer.latestVersion, installer.isUpdateAvailable {
                    HStack {
                        Text("v\(latest) available")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Spacer()
                        Button("Update") {
                            Task { await installer.install() }
                        }
                        .font(.caption)
                    }
                }
                if let error = installer.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Runbook Directory") {
                HStack {
                    TextField("Path", text: $runbookDir)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: runbookDir) {
                            AppSettings.runbookDir = runbookDir
                        }
                    Button("Browse...") { browseDirectory() }
                    Button("Reset") {
                        runbookDir = AppSettings.defaultRunbookDir
                        AppSettings.runbookDir = runbookDir
                    }
                    .foregroundStyle(.secondary)
                }
                Text("YAML runbook files are discovered from this directory and its subdirectories.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Editor") {
                HStack {
                    Text("Font Size")
                    Slider(value: $editorFontSize, in: 9...24, step: 1) {
                        Text("Font Size")
                    }
                    .onChange(of: editorFontSize) {
                        AppSettings.editorFontSize = editorFontSize
                    }
                    Text("\(Int(editorFontSize)) pt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 40)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .navigationTitle("Settings")
        .onAppear {
            installer.checkInstalledVersion()
        }
    }

    private func browseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: runbookDir)
        if panel.runModal() == .OK, let url = panel.url {
            runbookDir = url.path
            AppSettings.runbookDir = runbookDir
        }
    }
}
