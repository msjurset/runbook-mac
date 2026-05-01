import AppKit
import SwiftUI

@main
struct RunbookMacApp: App {
    @State private var store = RunbookStore()
    @State private var runSessions = RunSessionStore()
    @State private var showCLISetup = false

    init() {
        // Set app icon — try bundle resources, then relative to executable
        let candidates = [
            Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
            Bundle.main.bundlePath + "/Contents/Resources/AppIcon.icns",
        ]
        for path in candidates.compactMap({ $0 }) {
            if let icon = NSImage(contentsOfFile: path) {
                NSApplication.shared.applicationIconImage = icon
                break
            }
        }
    }

    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 0) {
                CLIUpdateBanner()
                ContentView()
                    .environment(store)
                    .environment(runSessions)
            }
            .onAppear {
                // Pick up external YAML edits / git pulls / new files
                // automatically — replaces what the bottom-strip Refresh
                // button used to do, plus catches files added outside the
                // app (which the manual refresh required the user to know
                // to press).
                store.startWatching()
                if !CLIInstaller.isCLIInstalled {
                    showCLISetup = true
                } else {
                    checkForCLIUpdate()
                }
            }
            .sheet(isPresented: $showCLISetup) {
                CLISetupSheet()
                    .environment(store)
            }
        }
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .help) {
                Button("Runbook Help") {
                    openWindow(id: "help")
                }
                .keyboardShortcut("?", modifiers: .command)
            }
            NavigateCommands()
        }

        Settings {
            SettingsView()
        }

        WindowGroup("Runbook Help", id: "help") {
            HelpView()
        }
        .defaultSize(width: 800, height: 550)
    }

    private func checkForCLIUpdate() {
        let installer = CLIInstaller()
        installer.checkInstalledVersion()
        guard installer.shouldCheckForUpdate() else { return }
        Task {
            await installer.checkLatestVersion()
        }
    }
}
