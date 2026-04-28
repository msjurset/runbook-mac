import Foundation

// Parses the runbook CLI's per-runbook log files to pull out the body lines
// for a single step in the most recent run that reached it. Format reminders:
//   - Runs separated by `--- run: <ts> ---` OR a `Running: <name> — …` banner.
//   - Each step starts with `▸ Step N: <name>`.
//   - Body lines are mostly prefixed with `  │ `; result lines (`  ✓ done`,
//     `  ✗ failed`, `  ⊘ skipped`) keep their two-space indent.
enum StepLogExtractor {
    /// Returns the body lines for `stepName` in the most recent run, or nil
    /// if the file is unreadable or the step never appears. Body excludes the
    /// `▸ Step` header but keeps the trailing result line for context.
    static func extractStepLines(logURL: URL, stepName: String, maxLines: Int = 200) -> String? {
        guard let raw = readPossiblyGzipped(url: logURL) else { return nil }
        // Don't pre-scope to "last run section" — append-mode logs may have a
        // recent run that didn't reach this step (e.g., killed in step 1).
        // The slice scans backwards so we land on the most recent occurrence.
        return slice(stepName: stepName, in: raw, scanBackwards: true, maxLines: maxLines)
    }

    /// Run-scoped variant for History: returns the body lines for `stepName`
    /// in the run referenced by `record`. `runIndexFromEnd` is the record's
    /// position in the runbook's history list sorted newest-first (0 = newest).
    /// Used as a fallback when the log run-marker doesn't carry a timestamp.
    static func extractStepLines(
        logURL: URL,
        stepName: String,
        record: HistoryRecord,
        runIndexFromEnd: Int,
        maxLines: Int = 200
    ) -> String? {
        guard let raw = readPossiblyGzipped(url: logURL) else { return nil }
        let section = scopeToRun(in: raw, record: record, runIndexFromEnd: runIndexFromEnd) ?? raw
        // Within the chosen section, scan FORWARD — we already know we're in
        // the correct run, so first hit is the right one.
        return slice(stepName: stepName, in: section, scanBackwards: false, maxLines: maxLines)
    }

    /// Resolve the most likely log file for a given run, trying the index
    /// first and then a few well-known fallbacks for cron-launched runs that
    /// aren't always recorded in the index.
    ///
    /// Files that were last written BEFORE the record's `startedDate` are
    /// rejected — they cannot possibly contain this run, and returning them
    /// causes the History view to show output from a different (typically
    /// older) run that happens to live in the same append-mode log file.
    static func findLogURL(for record: HistoryRecord) -> URL? {
        let fm = FileManager.default
        let recordStart = record.startedDate

        func mtime(of url: URL) -> Date {
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        }
        // 60s of slack absorbs minor clock-skew between record write and file flush
        func couldContainRun(_ url: URL) -> Bool {
            guard let target = recordStart else { return true }
            return mtime(of: url) >= target.addingTimeInterval(-60)
        }

        if let url = LogIndex.logPath(for: record), fm.fileExists(atPath: url.path) {
            return url
        }
        let candidates = [
            AppSettings.logsURL.appendingPathComponent("\(record.runbook_name).log"),
            AppSettings.historyURL.appendingPathComponent("\(record.runbook_name).log"),
        ]
        for url in candidates where fm.fileExists(atPath: url.path) && couldContainRun(url) {
            return url
        }
        // Fall back to scanning logs/ + archive/ for any file matching the
        // runbook name; pick newest by mtime that could plausibly contain
        // this run.
        let dirs = [
            AppSettings.logsURL,
            AppSettings.logsURL.appendingPathComponent("archive"),
        ]
        var newest: (URL, Date)?
        for dir in dirs {
            guard let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { continue }
            for entry in entries where entry.lastPathComponent.hasPrefix(record.runbook_name) {
                let ext = entry.pathExtension
                guard ext == "log" || ext == "gz", couldContainRun(entry) else { continue }
                let date = mtime(of: entry)
                if newest == nil || date > newest!.1 {
                    newest = (entry, date)
                }
            }
        }
        return newest?.0
    }

    private static func readPossiblyGzipped(url: URL) -> String? {
        if url.pathExtension == "gz" {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/gunzip")
            task.arguments = ["-c", url.path]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            do { try task.run() } catch { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            return String(data: data, encoding: .utf8)
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Locate the run section in `text` that corresponds to `record`. Tries:
    ///   1. `--- run: <ts>` markers within ±120s of record.startedDate.
    ///   2. Ordinal: split sections by run markers, pick `runIndexFromEnd`-th
    ///      from the end (works for `Running:`-only logs without timestamps).
    /// Returns nil if no sectioning is possible (single-run file → caller uses
    /// the whole text).
    private static func scopeToRun(
        in text: String,
        record: HistoryRecord,
        runIndexFromEnd: Int
    ) -> String? {
        // Walk lines, marking run-start positions. When `--- run:` and
        // `Running:` appear on adjacent lines (the CLI emits both at the
        // start of some runs), only the first one counts as a run boundary.
        var starts: [(lineIdx: Int, timestamp: Date?)] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        for (i, line) in lines.enumerated() {
            if line.hasPrefix("--- run:") {
                starts.append((i, parseRunTimestamp(from: line)))
            } else if line.hasPrefix("Running:") {
                if let last = starts.last, last.lineIdx == i - 1 { continue }
                starts.append((i, nil))
            }
        }
        guard !starts.isEmpty else { return nil }

        // Convert line indices back to character ranges for slicing.
        func sectionLines(at index: Int) -> ArraySlice<String> {
            let lo = starts[index].lineIdx
            let hi = (index + 1 < starts.count) ? starts[index + 1].lineIdx : lines.count
            return lines[lo..<hi]
        }

        let hasAnyTimestamps = starts.contains { $0.timestamp != nil }

        // 1. Timestamp match (preferred — accurate when CLI writes "--- run: <ts>").
        if let target = record.startedDate {
            var best: (idx: Int, delta: TimeInterval)?
            for (i, s) in starts.enumerated() {
                guard let ts = s.timestamp else { continue }
                let delta = abs(ts.timeIntervalSince(target))
                if best == nil || delta < best!.delta {
                    best = (i, delta)
                }
            }
            if let b = best, b.delta < 120 {
                return sectionLines(at: b.idx).joined(separator: "\n")
            }
            // Timestamps present but none within tolerance — this file does
            // not contain the requested run. Don't guess via ordinal.
            if hasAnyTimestamps { return nil }
        }
        // 2. Ordinal match — only when no timestamps exist anywhere in the
        // file (Running:-only logs). Count sections from the end.
        let ordinal = starts.count - 1 - runIndexFromEnd
        guard ordinal >= 0, ordinal < starts.count else { return nil }
        return sectionLines(at: ordinal).joined(separator: "\n")
    }

    private static func parseRunTimestamp(from line: String) -> Date? {
        // Format: "--- run: 2026-04-24T13:32:10 ---"
        let trimmed = line
            .replacingOccurrences(of: "--- run:", with: "")
            .replacingOccurrences(of: "---", with: "")
            .trimmingCharacters(in: .whitespaces)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = .current
        return formatter.date(from: trimmed)
    }

    private static func slice(stepName: String, in section: String, scanBackwards: Bool, maxLines: Int) -> String? {
        let lines = section.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var headerIdx: Int?

        if scanBackwards {
            // Schedule "last-run" view: find the MOST RECENT occurrence so a
            // freshly-failed run that never reached this step doesn't fool us.
            var i = lines.count - 1
            while i >= 0 {
                if matches(line: lines[i], stepName: stepName) { headerIdx = i; break }
                i -= 1
            }
        } else {
            // Run-scoped (History): we already know which run section we're
            // in, so the first match is the right one.
            for (i, line) in lines.enumerated() where matches(line: line, stepName: stepName) {
                headerIdx = i
                break
            }
        }
        guard let start = headerIdx else { return nil }

        var body: [String] = []
        var j = start + 1
        while j < lines.count {
            let line = lines[j]
            if line.hasPrefix("▸ Step ") { break }
            body.append(line)
            j += 1
        }
        while let last = body.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            body.removeLast()
        }

        let stripped = body.map { line -> String in
            if let r = line.range(of: "  │ ") { return String(line[r.upperBound...]) }
            return line
        }

        if stripped.count > maxLines {
            return stripped.prefix(maxLines).joined(separator: "\n") + "\n…"
        }
        return stripped.joined(separator: "\n")
    }

    private static func matches(line: String, stepName: String) -> Bool {
        guard line.hasPrefix("▸ Step "), let colon = line.range(of: ":") else { return false }
        return line[colon.upperBound...].trimmingCharacters(in: .whitespaces) == stepName
    }
}
