import Foundation
import Yams

/// Manages reading, writing, and discovering runbook YAML files.
@Observable
class RunbookStore {
    var runbooks: [Runbook] = []
    var templates: [Runbook] = []
    var historyRecords: [HistoryRecord] = []
    var pinnedNames: Set<String> = []

    private let booksDir: URL
    private let historyDir: URL
    private let pinnedFile: URL

    init() {
        booksDir = AppSettings.booksURL
        historyDir = AppSettings.historyURL
        pinnedFile = AppSettings.pinnedURL
        pinnedNames = loadPinned()
    }

    init(booksDir: URL, historyDir: URL, pinnedFile: URL) {
        self.booksDir = booksDir
        self.historyDir = historyDir
        self.pinnedFile = pinnedFile
        pinnedNames = loadPinned()
    }

    // MARK: - Discovery

    func loadAll() {
        let (discovered, discoveredTemplates) = discoverAll(in: booksDir)
        runbooks = discovered
        templates = discoveredTemplates
        historyRecords = loadHistory()
    }

    private func discoverAll(in dir: URL) -> (runbooks: [Runbook], templates: [Runbook]) {
        var books: [Runbook] = []
        var tmpls: [Runbook] = []
        scanDirectory(dir, books: &books, templates: &tmpls, inTemplatesDir: false)

        // Deduplicate each set by name: prefer shallower paths (local over repo)
        books = deduplicate(books)
        tmpls = deduplicate(tmpls)

        return (books, tmpls)
    }

    private func scanDirectory(_ dir: URL, books: inout [Runbook], templates: inout [Runbook], inTemplatesDir: Bool) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return }

        for entry in entries {
            if entry.hasDirectoryPath {
                let isTemplatesDir = entry.lastPathComponent.lowercased() == "templates"
                scanDirectory(entry, books: &books, templates: &templates, inTemplatesDir: inTemplatesDir || isTemplatesDir)
            } else if ["yaml", "yml"].contains(entry.pathExtension.lowercased()) {
                if var book = loadRunbook(at: entry) {
                    book.filePath = entry.path
                    if inTemplatesDir {
                        templates.append(book)
                    } else {
                        books.append(book)
                    }
                }
            }
        }
    }

    private func deduplicate(_ books: [Runbook]) -> [Runbook] {
        var seen: [String: Runbook] = [:]
        for book in books {
            if let existing = seen[book.name] {
                let existingDepth = existing.filePath?.components(separatedBy: "/").count ?? 0
                let newDepth = book.filePath?.components(separatedBy: "/").count ?? 0
                if newDepth < existingDepth {
                    seen[book.name] = book
                }
            } else {
                seen[book.name] = book
            }
        }
        return seen.values.sorted { $0.name < $1.name }
    }

    func loadRunbook(at url: URL) -> Runbook? {
        guard let data = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return try? YAMLDecoder().decode(Runbook.self, from: data)
    }

    // MARK: - CRUD

    func save(_ runbook: Runbook, to filename: String? = nil) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: booksDir, withIntermediateDirectories: true)

        let fname = filename ?? "\(runbook.name).yaml"
        let url = booksDir.appendingPathComponent(fname)

        backupIfExists(url)
        let yaml = try YAMLEncoder().encode(runbook)
        try yaml.write(to: url, atomically: true, encoding: .utf8)
    }

    func saveRaw(_ content: String, to filename: String) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: booksDir, withIntermediateDirectories: true)

        let url = booksDir.appendingPathComponent(filename)
        backupIfExists(url)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    func delete(_ runbook: Runbook) throws {
        guard let path = runbook.filePath else { return }
        backupIfExists(URL(fileURLWithPath: path))
        try FileManager.default.removeItem(atPath: path)
    }

    // MARK: - Backup

    private func backupIfExists(_ url: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }

        let backupsDir = AppSettings.backupsURL
        try? fm.createDirectory(at: backupsDir, withIntermediateDirectories: true)

        let name = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let timestamp = ISO8601DateFormatter.string(
            from: Date(),
            timeZone: .current,
            formatOptions: [.withFullDate, .withTime, .withDashSeparatorInDate]
        ).replacingOccurrences(of: ":", with: "-")
        let backupName = "\(name)-\(timestamp).\(ext)"
        let dest = backupsDir.appendingPathComponent(backupName)

        try? fm.copyItem(at: url, to: dest)
    }

    func readRawYAML(for runbook: Runbook) -> String? {
        guard let path = runbook.filePath else { return nil }
        return try? String(contentsOfFile: path, encoding: .utf8)
    }

    // MARK: - Pinning

    func isPinned(_ runbook: Runbook) -> Bool {
        pinnedNames.contains(runbook.name)
    }

    func togglePin(_ runbook: Runbook) {
        if pinnedNames.contains(runbook.name) {
            pinnedNames.remove(runbook.name)
        } else {
            pinnedNames.insert(runbook.name)
        }
        savePinned()
    }

    private func loadPinned() -> Set<String> {
        guard let data = try? Data(contentsOf: pinnedFile),
              let names = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(names)
    }

    private func savePinned() {
        let sorted = pinnedNames.sorted()
        guard let data = try? JSONEncoder().encode(sorted) else { return }
        try? data.write(to: pinnedFile)
    }

    // MARK: - History

    private func loadHistory() -> [HistoryRecord] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: historyDir, includingPropertiesForKeys: nil
        ) else { return [] }

        return entries
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> HistoryRecord? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(HistoryRecord.self, from: data)
            }
            .sorted { ($0.startedDate ?? .distantPast) > ($1.startedDate ?? .distantPast) }
    }

    func history(for runbookName: String) -> [HistoryRecord] {
        historyRecords.filter { $0.runbook_name == runbookName }
    }
}
