import Foundation

struct LogIndexData: Codable {
    var entries: [String: String] // history record ID → log file path
}

enum LogIndex {
    private static var indexURL: URL {
        AppSettings.logsURL.appendingPathComponent("index.json")
    }

    static func load() -> [String: String] {
        guard let data = try? Data(contentsOf: indexURL),
              let index = try? JSONDecoder().decode(LogIndexData.self, from: data) else {
            return [:]
        }
        return index.entries
    }

    static func save(_ entries: [String: String]) {
        let index = LogIndexData(entries: entries)
        guard let data = try? JSONEncoder().encode(index) else { return }
        try? FileManager.default.createDirectory(at: AppSettings.logsURL, withIntermediateDirectories: true)
        try? data.write(to: indexURL)
    }

    static func record(runbookName: String, startedAt: String, logPath: String) {
        var entries = load()
        let key = "\(runbookName)_\(startedAt)"
        entries[key] = logPath
        save(entries)
    }

    static func logPath(for record: HistoryRecord) -> URL? {
        let entries = load()
        let key = "\(record.runbook_name)_\(record.started_at)"
        guard let path = entries[key] else { return nil }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    static func defaultLogPath(runbookName: String) -> URL {
        let timestamp = ISO8601DateFormatter.string(
            from: Date(),
            timeZone: .current,
            formatOptions: [.withFullDate, .withTime, .withDashSeparatorInDate]
        ).replacingOccurrences(of: ":", with: "-")
        return AppSettings.logsURL.appendingPathComponent("\(runbookName)-\(timestamp).log")
    }

    static func logPath(for runbook: Runbook) -> URL {
        let logDir: URL
        if let dir = runbook.log?.dir {
            logDir = URL(fileURLWithPath: (dir as NSString).expandingTildeInPath)
        } else {
            logDir = AppSettings.logsURL
        }
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)

        if let filenameTemplate = runbook.log?.filename {
            let timestamp = ISO8601DateFormatter.string(
                from: Date(),
                timeZone: .current,
                formatOptions: [.withFullDate, .withTime, .withDashSeparatorInDate]
            ).replacingOccurrences(of: ":", with: "-")
            let filename = filenameTemplate
                .replacingOccurrences(of: "{name}", with: runbook.name)
                .replacingOccurrences(of: "{timestamp}", with: timestamp)
            return logDir.appendingPathComponent(filename + ".log")
        }

        return defaultLogPath(runbookName: runbook.name)
    }
}
