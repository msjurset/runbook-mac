import Foundation

struct LogIndexEntry: Codable {
    var logPath: String
    var runbookName: String
    var timestamp: Date
}

struct LogIndexData: Codable {
    var entries: [LogIndexEntry]
}

enum LogIndex {
    private static var indexURL: URL {
        AppSettings.logsURL.appendingPathComponent("index.json")
    }

    static func load() -> [LogIndexEntry] {
        guard let data = try? Data(contentsOf: indexURL),
              let index = try? JSONDecoder().decode(LogIndexData.self, from: data) else {
            return []
        }
        return index.entries
    }

    static func save(_ entries: [LogIndexEntry]) {
        let index = LogIndexData(entries: entries)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(index) else { return }
        try? FileManager.default.createDirectory(at: AppSettings.logsURL, withIntermediateDirectories: true)
        try? data.write(to: indexURL)
    }

    static func record(runbookName: String, date: Date, logPath: String) {
        var entries = load()
        // Remove any existing entry for the same log path
        entries.removeAll { $0.logPath == logPath }
        entries.append(LogIndexEntry(logPath: logPath, runbookName: runbookName, timestamp: date))
        save(entries)
    }

    static func logPath(for record: HistoryRecord) -> URL? {
        guard let recordDate = record.startedDate else { return nil }
        let entries = load()

        // Find the closest entry for this runbook within 60 seconds
        let candidates = entries.filter { $0.runbookName == record.runbook_name }
        guard let best = candidates.min(by: {
            abs($0.timestamp.timeIntervalSince(recordDate)) < abs($1.timestamp.timeIntervalSince(recordDate))
        }) else { return nil }

        // Must be within 60 seconds
        guard abs(best.timestamp.timeIntervalSince(recordDate)) < 60 else { return nil }

        let url = URL(fileURLWithPath: best.logPath)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    /// Update an entry's log path (used by log rotation).
    static func updatePath(oldPath: String, newPath: String) {
        var entries = load()
        for i in entries.indices {
            if entries[i].logPath == oldPath {
                entries[i].logPath = newPath
            }
        }
        save(entries)
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
