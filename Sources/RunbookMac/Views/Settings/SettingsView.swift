import SwiftUI

struct SettingsView: View {
    @State private var runbookDir = AppSettings.runbookDir
    @State private var editorFontSize = AppSettings.editorFontSize

    var body: some View {
        Form {
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
