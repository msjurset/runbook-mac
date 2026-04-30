import Foundation

/// App-level store for in-flight and recently-completed runbook executions.
/// Concurrent runs are supported — launching a new run while others are
/// still running adds it to the list and makes it the tray's active
/// session. The tray renders one session at a time; a small picker in the
/// header switches between them when more than one is present.
@Observable
@MainActor
final class RunSessionStore {
    /// All active + recently-completed sessions, ordered newest first.
    /// Active sessions stay until completion; terminal sessions stay until
    /// explicitly dismissed (with a cap of 5 retained terminal sessions so
    /// the list can't grow forever).
    private(set) var sessions: [RunSession] = []

    /// ID of the session currently shown in the tray. `nil` when no session
    /// has been started or the last one was dismissed.
    var currentID: UUID?

    /// Whether the tray is expanded (full output panel) or collapsed (single
    /// status line). Defaults to expanded on first run.
    var isExpanded: Bool = true

    private var runTasks: [UUID: Task<Void, Never>] = [:]
    private let terminalRetention = 5

    /// Session the tray is currently showing.
    var current: RunSession? {
        guard let id = currentID else { return nil }
        return sessions.first { $0.id == id }
    }

    /// Count of sessions still running.
    var runningCount: Int {
        sessions.filter { $0.state == .running }.count
    }

    /// Start a new run. Always succeeds — concurrent runs are allowed.
    /// Returns the new session's id so callers can optionally track it.
    @discardableResult
    func start(runbook: Runbook, vars: [String: String], dryRun: Bool) -> UUID {
        let session = RunSession(
            runbookName: runbook.name,
            dryRun: dryRun,
            vars: vars,
            startedAt: Date()
        )
        sessions.insert(session, at: 0)
        currentID = session.id
        isExpanded = true

        let sessionID = session.id
        // RunSessionStore has app lifetime (owned by @State in the App
        // scene), so strong `self` capture here doesn't cycle.
        runTasks[sessionID] = Task {
            do {
                let success = try await RunbookCLI.shared.run(
                    name: runbook.name,
                    vars: vars,
                    dryRun: dryRun
                ) { line in
                    Task { @MainActor in
                        self.append(line, to: sessionID)
                    }
                }
                await MainActor.run {
                    self.finish(sessionID: sessionID,
                                state: success ? .succeeded : .failed("runbook reported failure"))
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.append("— Cancelled —", to: sessionID)
                    self.finish(sessionID: sessionID, state: .cancelled)
                }
            } catch {
                await MainActor.run {
                    self.append("Error: \(error.localizedDescription)", to: sessionID)
                    self.finish(sessionID: sessionID, state: .failed(error.localizedDescription))
                }
            }
        }
        return session.id
    }

    /// Cancel the session currently shown in the tray.
    func cancelCurrent() {
        guard let id = currentID else { return }
        cancel(sessionID: id)
    }

    /// Cancel a specific session by id.
    func cancel(sessionID: UUID) {
        runTasks[sessionID]?.cancel()
    }

    /// Dismiss the currently-shown session from the list. No-op while it's
    /// still running — caller should cancel first.
    func dismissCurrent() {
        guard let id = currentID,
              let session = sessions.first(where: { $0.id == id }),
              session.state.isTerminal else { return }
        sessions.removeAll { $0.id == id }
        runTasks[id] = nil
        // Fall back to the next session (most recent running, else most recent overall).
        currentID = sessions.first(where: { $0.state == .running })?.id
            ?? sessions.first?.id
    }

    /// Switch the tray's focus to a specific session.
    func show(_ id: UUID) { currentID = id }

    /// Rerun a terminal session *in place*: resets its output, flips state
    /// back to `running`, refreshes `startedAt`, and kicks a new subprocess
    /// task. Keeps the same session id / tab — no new tab is created. No-op
    /// if the session is not in a terminal state or has been dropped.
    ///
    /// `dryRun` and `vars` override the original captured values when
    /// provided (used by "Retry as real/dry run" and "Retry with different
    /// inputs…"). Passing nil means reuse what was there.
    func restart(sessionID: UUID,
                 runbook: Runbook,
                 dryRun: Bool? = nil,
                 vars: [String: String]? = nil) {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionID }),
              sessions[idx].state.isTerminal else { return }
        let resolvedDry = dryRun ?? sessions[idx].dryRun
        let resolvedVars = vars ?? sessions[idx].vars
        sessions[idx].output = []
        sessions[idx].state = .running
        sessions[idx].endedAt = nil
        sessions[idx].startedAt = Date()
        sessions[idx].dryRun = resolvedDry
        sessions[idx].vars = resolvedVars
        currentID = sessionID
        isExpanded = true

        runTasks[sessionID] = Task {
            do {
                let success = try await RunbookCLI.shared.run(
                    name: runbook.name,
                    vars: resolvedVars,
                    dryRun: resolvedDry
                ) { line in
                    Task { @MainActor in
                        self.append(line, to: sessionID)
                    }
                }
                await MainActor.run {
                    self.finish(sessionID: sessionID,
                                state: success ? .succeeded : .failed("runbook reported failure"))
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.append("— Cancelled —", to: sessionID)
                    self.finish(sessionID: sessionID, state: .cancelled)
                }
            } catch {
                await MainActor.run {
                    self.append("Error: \(error.localizedDescription)", to: sessionID)
                    self.finish(sessionID: sessionID, state: .failed(error.localizedDescription))
                }
            }
        }
    }

    /// Remove a session regardless of state — intended for the tab-× control
    /// where the user has already accepted that stop+dismiss is atomic. The
    /// cancel should have been issued separately (or will be, and the task's
    /// completion handler is a no-op once its session is gone).
    func forceRemove(sessionID: UUID) {
        let wasCurrent = currentID == sessionID
        sessions.removeAll { $0.id == sessionID }
        runTasks[sessionID] = nil
        if wasCurrent {
            currentID = sessions.first(where: { $0.state == .running })?.id
                ?? sessions.first?.id
        }
    }

    /// Toggle expanded/collapsed.
    func toggle() { isExpanded.toggle() }

    // MARK: - Mutations (main actor)

    private func append(_ line: String, to sessionID: UUID) {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[idx].output.append(line)
    }

    private func finish(sessionID: UUID, state: RunSession.State) {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[idx].endedAt = Date()
        sessions[idx].state = state
        runTasks[sessionID] = nil
        persistLog(for: sessions[idx])
        pruneTerminal()
    }

    /// Save the captured output to a log file so the History and Schedules
    /// views can show per-step slices of Mac-app-launched runs (cron runs are
    /// already captured by launchd's stdout redirect).
    ///
    /// We always write a per-run file and record it in `LogIndex`. If the
    /// runbook itself has `log:` configured, the CLI also wrote its own file —
    /// that's harmless duplication; the index points to ours so History
    /// resolves consistently against the run's `started_at`.
    ///
    /// Dry runs are skipped: the CLI doesn't write a history record for
    /// `--dry-run`, so persisting a log file here would create an orphan
    /// (no history row points at it, no view surfaces it). End-to-end this
    /// keeps "dry runs leave no trace" consistent with the CLI.
    private func persistLog(for session: RunSession) {
        guard !session.dryRun else { return }
        guard !session.output.isEmpty else { return }
        let logURL = LogIndex.defaultLogPath(runbookName: session.runbookName)
        // The CLI's stream strips trailing newlines per line, so rejoin with
        // explicit newlines. The CLI already emits its own "Running: <name>"
        // banner so the resulting file already has a parseable run marker.
        let text = session.output.joined(separator: "\n") + "\n"
        do {
            try FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: logURL, atomically: true, encoding: .utf8)
            LogIndex.record(runbookName: session.runbookName, date: session.startedAt, logPath: logURL.path)
        } catch {
            // Logging is best-effort; failing to write shouldn't break the run.
        }
    }

    /// Keep at most `terminalRetention` terminal sessions around, dropping
    /// the oldest terminal ones first. Active (running) sessions are never
    /// pruned.
    private func pruneTerminal() {
        let terminalIdxs = sessions.indices.filter { sessions[$0].state.isTerminal }
        guard terminalIdxs.count > terminalRetention else { return }
        // sessions is newest-first; terminalIdxs respects that, so the last
        // entries in terminalIdxs are the oldest terminal sessions.
        let toDrop = terminalIdxs.suffix(terminalIdxs.count - terminalRetention)
        let dropIDs = Set(toDrop.map { sessions[$0].id })
        sessions.removeAll { dropIDs.contains($0.id) }
        // If we dropped the currently-shown session, fall forward.
        if let id = currentID, dropIDs.contains(id) {
            currentID = sessions.first?.id
        }
    }
}
