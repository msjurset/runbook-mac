import AppKit
import SwiftUI

@main
struct RunbookMacApp: App {
    @State private var store = RunbookStore()

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
            ContentView()
                .environment(store)
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
}
