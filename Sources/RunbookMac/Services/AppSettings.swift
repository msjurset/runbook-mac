import Foundation

enum AppSettings {
    nonisolated(unsafe) private static let defaults = UserDefaults.standard

    static var runbookDir: String {
        get { defaults.string(forKey: "runbookDir") ?? defaultRunbookDir }
        set { defaults.set(newValue, forKey: "runbookDir") }
    }

    static var editorFontSize: Double {
        get {
            let val = defaults.double(forKey: "editorFontSize")
            return val > 0 ? val : 12
        }
        set { defaults.set(newValue, forKey: "editorFontSize") }
    }

    static var defaultRunbookDir: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".runbook/books").path
    }

    static var booksURL: URL {
        URL(fileURLWithPath: runbookDir)
    }

    static var baseURL: URL {
        booksURL.deletingLastPathComponent()
    }

    static var historyURL: URL {
        baseURL.appendingPathComponent("history")
    }

    static var pinnedURL: URL {
        baseURL.appendingPathComponent("pinned.json")
    }

    static var logsURL: URL {
        baseURL.appendingPathComponent("logs")
    }

    static var backupsURL: URL {
        baseURL.appendingPathComponent("backups")
    }
}
