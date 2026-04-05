import Foundation
import Yams

/// Manages reading, writing, and discovering runbook YAML files.
@Observable
class RunbookStore {
    var runbooks: [Runbook] = []
    var templates: [Runbook] = []
    var historyRecords: [HistoryRecord] = []

    private let booksDir: URL
    private let historyDir: URL

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        booksDir = home.appendingPathComponent(".runbook/books")
        historyDir = home.appendingPathComponent(".runbook/history")
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

        let yaml = try YAMLEncoder().encode(runbook)
        try yaml.write(to: url, atomically: true, encoding: .utf8)
    }

    func saveRaw(_ content: String, to filename: String) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: booksDir, withIntermediateDirectories: true)

        let url = booksDir.appendingPathComponent(filename)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    func delete(_ runbook: Runbook) throws {
        guard let path = runbook.filePath else { return }
        try FileManager.default.removeItem(atPath: path)
    }

    func readRawYAML(for runbook: Runbook) -> String? {
        guard let path = runbook.filePath else { return nil }
        return try? String(contentsOfFile: path, encoding: .utf8)
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
