import SwiftUI

/// One row in the inline schedule editor's variables section. Stable id
/// lets ForEach track rows across edits (rename, value typing, reorder)
/// without forcing the entire list to remount on every keystroke.
struct CronVarPair: Identifiable, Equatable {
    let id: UUID
    var key: String
    var value: String

    init(id: UUID = UUID(), key: String = "", value: String = "") {
        self.id = id
        self.key = key
        self.value = value
    }
}

extension Array where Element == String {
    /// Convert a list of "key=value" strings (the wire format used by
    /// `runbook cron list` and `runbook cron add --var`) into editable
    /// pairs. Tokens lacking an "=" or with an empty key are dropped —
    /// they couldn't round-trip back through `--var` anyway.
    func asCronVarPairs() -> [CronVarPair] {
        compactMap { s -> CronVarPair? in
            guard let eq = s.firstIndex(of: "=") else { return nil }
            let key = String(s[..<eq])
            let value = String(s[s.index(after: eq)...])
            guard !key.isEmpty else { return nil }
            return CronVarPair(key: key, value: value)
        }
    }
}

extension Array where Element == CronVarPair {
    /// Render to the "key=value" wire format the CLI consumes. Trims
    /// whitespace from the key, drops empty-key rows (the user typed
    /// nothing into a placeholder slot), but preserves empty values
    /// because `--var x=` is a meaningful "set to empty string" signal.
    func asCronVarStrings() -> [String] {
        compactMap { p in
            let k = p.key.trimmingCharacters(in: .whitespaces)
            guard !k.isEmpty else { return nil }
            return "\(k)=\(p.value)"
        }
    }
}

struct CronView: View {
    struct ScheduleEntry: Identifiable {
        var id: String { "\(name)|\(schedule)" }
        var name: String
        var schedule: String
        /// Free-form remainder column from `runbook cron list` after the
        /// schedule. Today this is backend + vars joined as one string;
        /// retained for diagnostics but not rendered directly.
        var command: String
        var description: String
        /// Per-schedule CLI variables baked in via `runbook cron add --var
        /// key=value`. Each entry is a "key=value" string. Empty for plain
        /// schedules with no vars.
        var vars: [String]
        /// Backend label from the CLI: "cron" or "launchd". Drives a
        /// subtle visual distinction in the row footer; doesn't affect
        /// behavior in the UI.
        var backend: String
    }

    /// A runbook plus every schedule installed for it. The Schedules view
    /// groups by name so a runbook scheduled multiple times (e.g. a daily
    /// AND a monthly variant) shows one header + one step pipeline +
    /// per-schedule sub-rows instead of duplicating the entire card.
    struct RunbookGroup: Identifiable {
        var id: String { name }
        var name: String
        var schedules: [ScheduleEntry]

        /// Earliest upcoming fire time across this group's schedules. Used
        /// to sort groups so the most-imminent runbook bubbles to the top
        /// of the list.
        func earliestNext(now: Date = Date()) -> Date {
            schedules.compactMap { CronNextRun.next(for: $0.schedule, after: now) }.min() ?? .distantFuture
        }
    }

    @State private var schedules: [ScheduleEntry] = []
    @State private var isLoading = false
    @State private var showAdd = false
    @State private var newName = ""
    @State private var newSchedule = ""
    /// Pending `--var` rows for the Add form. Reset alongside `newName`
    /// and `newSchedule` whenever a schedule is successfully added.
    @State private var newVars: [CronVarPair] = []
    @State private var errorMessage: String?
    @State private var cronDescription = ""
    @State private var editingName: String?
    @State private var editSchedule = ""
    /// Editable `--var` payload for the row currently being edited. Lives
    /// at the parent so the same state survives view-identity churn from
    /// reordering inside ForEach, and so the per-row Save handler can
    /// read both `editSchedule` and `editVars` in one shot.
    @State private var editVars: [CronVarPair] = []
    /// ID of the row whose content area the mouse is currently inside, or nil.
    /// Drives single-row legend visibility — entering a row clears any other
    /// row's legend by virtue of the binding holding only one id at a time.
    @State private var hoveredRowID: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Scheduled Runbooks")
                    .font(.headline)
                Spacer()
                Button("Add Schedule", systemImage: "plus") {
                    showAdd.toggle()
                }
                Button("Refresh", systemImage: "arrow.clockwise") {
                    loadCronList()
                }
            }
            .padding()

            Divider()

            if showAdd {
                CronAddForm(
                    name: $newName,
                    schedule: $newSchedule,
                    cronDescription: $cronDescription,
                    vars: $newVars,
                    onAdd: addSchedule
                )
                Divider()
            }

            if let err = errorMessage {
                ErrorBanner(message: err) { errorMessage = nil }
            }

            if schedules.isEmpty && !isLoading {
                ContentUnavailableView(
                    "No Schedules",
                    systemImage: "calendar.badge.clock",
                    description: Text("Add a cron schedule to run runbooks automatically.")
                )
            } else {
                List {
                    ForEach(groupedSchedules) { group in
                        if group.schedules.count == 1 {
                            // Single-schedule runbook: keep the existing card
                            // layout so users with one schedule see no
                            // visual change.
                            CronScheduleRow(
                                entry: group.schedules[0],
                                editingName: $editingName,
                                editSchedule: $editSchedule,
                                editVars: $editVars,
                                hoveredRowID: $hoveredRowID,
                                onUpdate: updateSchedule,
                                onRemove: removeSchedule
                            )
                        } else {
                            // Multiple schedules on the same runbook: one
                            // header + one step pipeline + per-schedule
                            // sub-rows. Cuts duplication for the daily/
                            // monthly-variant pattern.
                            CronRunbookGroupView(
                                group: group,
                                editingName: $editingName,
                                editSchedule: $editSchedule,
                                editVars: $editVars,
                                hoveredRowID: $hoveredRowID,
                                onUpdate: updateSchedule,
                                onRemove: removeSchedule
                            )
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .navigationTitle("Schedules")
        .toolbar {
            ToolbarItem {
                ContextualHelpButton(topic: .scheduling)
            }
        }
        .onAppear { loadCronList() }
    }

    // MARK: - Data

    private func loadCronList() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let result = try await RunbookCLI.shared.cronList()
                await MainActor.run {
                    schedules = parseCronList(result)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func parseCronList(_ text: String) -> [ScheduleEntry] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard lines.count > 1 else { return [] }

        // Columns from `runbook cron list`:
        //     RUNBOOK   SCHEDULE   BACKEND   VARS
        // After splitting the line into whitespace-separated tokens, the
        // first 5 tokens after the name form the schedule, token 6 is the
        // backend, and the remainder is the var list (or "-" if none).
        var entries: [ScheduleEntry] = []
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.components(separatedBy: "  ").filter { !$0.isEmpty }.map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2 else { continue }

            let name = parts[0]
            var remainder = trimmed
            if let nameRange = remainder.range(of: name) {
                remainder = String(remainder[nameRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            }

            let tokens = remainder.split(separator: " ").map(String.init)
            guard tokens.count >= 5 else { continue }

            let schedule = tokens[0...4].joined(separator: " ")
            let backend = tokens.count > 5 ? tokens[5] : "cron"
            let varTokens = tokens.count > 6 ? Array(tokens[6...]) : []
            // CLI emits "-" for "no vars"; strip that single-token sentinel
            // so we have a clean empty array for downstream rendering.
            let vars: [String]
            if varTokens.count == 1 && varTokens[0] == "-" {
                vars = []
            } else {
                vars = varTokens
            }
            let command = tokens.count > 5 ? tokens[5...].joined(separator: " ") : ""

            entries.append(ScheduleEntry(
                name: name,
                schedule: schedule,
                command: command,
                description: CronDescription.describe(schedule),
                vars: vars,
                backend: backend
            ))
        }
        // Sort by next fire time so the most-imminent job is on top.
        // Schedules whose expression can't be parsed sort to the bottom.
        return entries.sorted { lhs, rhs in
            let lNext = CronNextRun.next(for: lhs.schedule) ?? .distantFuture
            let rNext = CronNextRun.next(for: rhs.schedule) ?? .distantFuture
            return lNext < rNext
        }
    }

    /// Bundle the flat schedule list into per-runbook groups so the view
    /// can render one header + one pipeline per runbook when multiple
    /// schedules exist. Groups are sorted by earliest upcoming fire time;
    /// within a group, schedules retain the parse-order sort by next-run.
    private var groupedSchedules: [RunbookGroup] {
        var byName: [String: [ScheduleEntry]] = [:]
        var order: [String] = []
        for s in schedules {
            if byName[s.name] == nil { order.append(s.name) }
            byName[s.name, default: []].append(s)
        }
        let now = Date()
        return order.map { name in
            RunbookGroup(name: name, schedules: byName[name] ?? [])
        }.sorted { lhs, rhs in
            lhs.earliestNext(now: now) < rhs.earliestNext(now: now)
        }
    }

    private func addSchedule() {
        errorMessage = nil
        let vars = newVars.asCronVarStrings()
        Task {
            do {
                _ = try await RunbookCLI.shared.cronAdd(name: newName, schedule: newSchedule, vars: vars)
                await MainActor.run {
                    newName = ""
                    newSchedule = ""
                    newVars = []
                    showAdd = false
                }
                loadCronList()
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    private func updateSchedule(name: String) {
        let oldSchedule = schedules.first { $0.id == editingName }?.schedule
        errorMessage = nil
        let newSched = editSchedule
        let newVars = editVars.asCronVarStrings()
        Task {
            do {
                if let old = oldSchedule {
                    _ = try await RunbookCLI.shared.cronRemove(name: name, schedule: old)
                }
                _ = try await RunbookCLI.shared.cronAdd(name: name, schedule: newSched, vars: newVars)
                await MainActor.run {
                    editingName = nil
                    editVars = []
                }
                loadCronList()
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    private func removeSchedule(name: String, schedule: String) {
        errorMessage = nil
        Task {
            do {
                _ = try await RunbookCLI.shared.cronRemove(name: name, schedule: schedule)
                loadCronList()
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }
}
