import SwiftUI

struct CronView: View {
    struct ScheduleEntry: Identifiable {
        var id: String { "\(name)|\(schedule)" }
        var name: String
        var schedule: String
        var command: String
        var description: String
    }

    @Environment(RunbookStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @State private var output = ""
    @State private var schedules: [ScheduleEntry] = []
    @State private var isLoading = false
    @State private var showAdd = false
    @State private var newName = ""
    @State private var newSchedule = ""
    @State private var errorMessage: String?
    @FocusState private var isNameFocused: Bool
    @FocusState private var isScheduleFocused: Bool
    @State private var cronDescription = ""
    @State private var editingName: String?
    @State private var editSchedule = ""

    private var filteredRunbooks: [Runbook] {
        if newName.isEmpty {
            return store.runbooks
        }
        return store.runbooks.filter {
            $0.name.localizedCaseInsensitiveContains(newName)
        }
    }

    private var showSuggestions: Bool {
        guard isNameFocused else { return false }
        // Don't show if the name exactly matches a runbook
        if store.runbooks.contains(where: { $0.name == newName }) { return false }
        return !filteredRunbooks.isEmpty
    }

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
                addScheduleForm
                Divider()
            }

            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
            }

            if schedules.isEmpty && !isLoading {
                ContentUnavailableView(
                    "No Schedules",
                    systemImage: "calendar.badge.clock",
                    description: Text("Add a cron schedule to run runbooks automatically.")
                )
            } else {
                List {
                    ForEach(schedules) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            // Header: name + actions
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 18)
                                Text(entry.name)
                                    .font(.headline)
                                Spacer()
                                Button {
                                    if editingName == entry.id {
                                        editingName = nil
                                    } else {
                                        editingName = entry.id
                                        editSchedule = entry.schedule
                                    }
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.secondary)
                                .help("Edit schedule")
                                Button(role: .destructive) {
                                    removeSchedule(name: entry.name, schedule: entry.schedule)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.secondary)
                                .help("Remove schedule")
                            }

                            if editingName == entry.id {
                                HStack(spacing: 8) {
                                    Image(systemName: "clock")
                                        .foregroundStyle(.secondary)
                                    TextField("Cron schedule", text: $editSchedule)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(maxWidth: 200)
                                        .onSubmit { updateSchedule(name: entry.name) }
                                    Button("Save") { updateSchedule(name: entry.name) }
                                        .disabled(editSchedule.isEmpty)
                                    Button("Cancel") { editingName = nil }
                                }

                                if !editSchedule.isEmpty {
                                    Text(describeCron(editSchedule))
                                        .font(.callout)
                                        .foregroundStyle(.orange)
                                }
                            } else {
                                // Schedule info
                                HStack(alignment: .center, spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 18, height: 18)
                                    Text(entry.schedule)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundStyle(.primary)
                                    Text(entry.description)
                                        .font(.callout)
                                        .foregroundStyle(.orange)
                                        .padding(.leading, 8)
                                }

                                // Step flowchart
                                if let book = store.runbooks.first(where: { $0.name == entry.name }) {
                                    StepFlowCanvas(steps: book.steps, colorScheme: colorScheme)
                                }
                            }
                        }
                        .padding(.vertical, 4)
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

    private var addScheduleForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Row 1: Runbook name with autocomplete
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Runbook")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Name", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .focused($isNameFocused)

                    if showSuggestions {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredRunbooks.prefix(8)) { book in
                                Button {
                                    newName = book.name
                                    isNameFocused = false
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.text")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(book.name)
                                            .font(.body)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if book.id != filteredRunbooks.prefix(8).last?.id {
                                    Divider()
                                }
                            }
                        }
                        .background(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.quaternary)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    }
                }
                .frame(maxWidth: 250)

                Spacer()

                Button("Add") { addSchedule() }
                    .disabled(newName.isEmpty || newSchedule.isEmpty)
                    .controlSize(.large)
                    .padding(.top, 16)
            }

            // Row 2: Cron schedule with description + diagram
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Schedule")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g., 0 3 * * 0", text: $newSchedule)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                        .focused($isScheduleFocused)
                        .onChange(of: isScheduleFocused) { _, focused in
                            if !focused {
                                cronDescription = describeCron(newSchedule)
                            }
                        }
                        .onSubmit {
                            cronDescription = describeCron(newSchedule)
                        }

                    if !cronDescription.isEmpty {
                        Text(cronDescription)
                            .font(.callout)
                            .foregroundStyle(.orange)
                            .padding(.top, 2)
                    }
                }

                cronDiagram
                    .padding(.top, 2)
            }
        }
        .padding()
    }

    private var cronDiagram: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                Text("┌───────── minute (0-59)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("│ ┌─────── hour (0-23)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("│ │ ┌───── day of month (1-31)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("│ │ │ ┌─── month (1-12)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("│ │ │ │ ┌─ day of week (0-6, Sun=0)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("* * * * *")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                cronLegendRow("*", "every value")
                cronLegendRow(",", "list: 1,3,5")
                cronLegendRow("-", "range: 1-5")
                cronLegendRow("/", "step: */15 (every 15)")
            }
        }
    }

    @ViewBuilder
    private func stepPipelineFlow(steps: [Step]) -> some View {
        GeometryReader { geo in
            let rows = computeRows(steps: steps, maxWidth: geo.size.width)
            let rowHeight: CGFloat = 26
            let turnHeight: CGFloat = 22
            let totalHeight = CGFloat(rows.count) * rowHeight + CGFloat(max(0, rows.count - 1)) * turnHeight

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, row in
                    let reversed = rowIdx % 2 == 1
                    let orderedRow = reversed ? row.reversed() : row

                    // Turn connector between rows
                    if rowIdx > 0 {
                        let fromRight = (rowIdx - 1) % 2 == 0
                        HStack(spacing: 0) {
                            if fromRight {
                                Spacer()
                                TurnPipe(direction: .rightDown)
                                    .frame(width: 16, height: turnHeight)
                            } else {
                                TurnPipe(direction: .leftDown)
                                    .frame(width: 16, height: turnHeight)
                                Spacer()
                            }
                        }
                    }

                    // Step row
                    HStack(spacing: 0) {
                        if reversed { Spacer(minLength: 0) }
                        HStack(spacing: 0) {
                            ForEach(Array(orderedRow.enumerated()), id: \.offset) { i, step in
                                if i > 0 {
                                    StepArrow(direction: reversed ? .left : .right)
                                        .frame(width: 24, height: rowHeight)
                                }
                                stepPill(step)
                            }
                        }
                        if !reversed { Spacer(minLength: 0) }
                    }
                    .frame(height: rowHeight)
                }
            }
        }
        .frame(minHeight: CGFloat(computeRows(steps: steps, maxWidth: 350).count) * 28 + CGFloat(max(0, computeRows(steps: steps, maxWidth: 350).count - 1)) * 22)
    }

    private func computeRows(steps: [Step], maxWidth: CGFloat) -> [[Step]] {
        var rows: [[Step]] = [[]]
        var currentWidth: CGFloat = 0
        let arrowWidth: CGFloat = 24

        for step in steps {
            let pillW = estimatePillWidth(step)
            let needed = currentWidth > 0 ? pillW + arrowWidth : pillW
            if currentWidth + needed > maxWidth && currentWidth > 0 {
                rows.append([])
                currentWidth = 0
            }
            rows[rows.count - 1].append(step)
            currentWidth += needed
        }
        return rows
    }

    private func estimatePillWidth(_ step: Step) -> CGFloat {
        let name = abbreviate(step.name, max: 16)
        return CGFloat(name.count) * 6.2 + 22
    }

    private func stepPill(_ step: Step) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(stepColor(step))
                .frame(width: 3, height: 12)
            Text(abbreviate(step.name, max: 16))
                .font(.system(.caption2, weight: .medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.fill.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(stepColor(step).opacity(0.3), lineWidth: 0.5)
        )
    }

    private func stepColor(_ step: Step) -> Color {
        if step.confirm != nil { return .orange }
        switch step.type {
        case "ssh": return .teal
        case "http": return .green
        default: return .blue
        }
    }

    private func abbreviate(_ s: String, max: Int) -> String {
        if s.count <= max { return s }
        return String(s.prefix(max - 1)) + "…"
    }

    private func cronLegendRow(_ symbol: String, _ desc: String) -> some View {
        HStack(spacing: 6) {
            Text(symbol)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.orange)
                .frame(width: 16, alignment: .center)
            Text(desc)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func describeCron(_ expr: String) -> String {
        let parts = expr.trimmingCharacters(in: .whitespaces).split(separator: " ").map(String.init)
        guard parts.count == 5 else { return "" }

        let minute = parts[0]
        let hour = parts[1]
        let dom = parts[2]
        let month = parts[3]
        let dow = parts[4]

        let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let monthNames = ["", "January", "February", "March", "April", "May", "June",
                          "July", "August", "September", "October", "November", "December"]

        // Build the frequency/time part
        var time = ""
        if minute == "*" && hour == "*" {
            time = "Every minute"
        } else if minute.hasPrefix("*/") && hour == "*" {
            time = "Every \(minute.dropFirst(2)) minutes"
        } else if minute.hasPrefix("*/") {
            let h = Int(hour) ?? 0
            let ampm = h >= 12 ? "PM" : "AM"
            let h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
            time = "Every \(minute.dropFirst(2)) minutes past \(h12) \(ampm)"
        } else if hour.hasPrefix("*/") {
            time = "At minute \(minute), every \(hour.dropFirst(2)) hours"
        } else if hour == "*" {
            time = "At minute \(minute) of every hour"
        } else if hour.contains(",") {
            let hours = hour.split(separator: ",").compactMap { Int($0) }.map { h in
                let ampm = h >= 12 ? "PM" : "AM"
                let h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
                return "\(h12) \(ampm)"
            }
            time = "At minute \(minute) past \(hours.joined(separator: " and "))"
        } else {
            let h = Int(hour) ?? 0
            let m = Int(minute) ?? 0
            let ampm = h >= 12 ? "PM" : "AM"
            let h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
            time = String(format: "At %d:%02d %@", h12, m, ampm)
        }

        // Build the "when" part
        let allDaysWild = dom == "*" && dow == "*"
        let monthWild = month == "*"

        var when = ""

        if allDaysWild && monthWild {
            when = "every day"
        } else {
            // Describe day-of-week
            var dowDesc = ""
            if dow != "*" {
                if dow.contains("/") {
                    let stepParts = dow.split(separator: "/")
                    let start = String(stepParts[0])
                    let step = String(stepParts.count > 1 ? stepParts[1] : "")
                    if start == "*" {
                        dowDesc = "every \(step) days of the week"
                    } else if let d = Int(start), d >= 0, d <= 6 {
                        dowDesc = "every \(step) days starting on \(dayNames[d])"
                    }
                } else if let d = Int(dow), d >= 0, d <= 6 {
                    dowDesc = "on \(dayNames[d])s"
                } else if dow.contains(",") {
                    let days = dow.split(separator: ",").compactMap { Int($0) }.compactMap { d in
                        d >= 0 && d <= 6 ? dayNames[d] : nil
                    }
                    dowDesc = "on \(days.joined(separator: " and "))"
                } else if dow.contains("-") {
                    let range = dow.split(separator: "-").compactMap { Int($0) }
                    if range.count == 2, range[0] >= 0, range[1] <= 6 {
                        dowDesc = "\(dayNames[range[0]]) through \(dayNames[range[1]])"
                    }
                }
            }

            // Describe day-of-month
            var domDesc = ""
            if dom != "*" {
                if dom.contains("/") {
                    let stepParts = dom.split(separator: "/")
                    let start = String(stepParts[0])
                    let step = String(stepParts.count > 1 ? stepParts[1] : "")
                    if start == "*" {
                        domDesc = "every \(step) days"
                    } else {
                        domDesc = "every \(step) days starting on the \(ordinal(start))"
                    }
                } else if dom.contains(",") {
                    let days = dom.split(separator: ",").map { ordinal(String($0)) }
                    domDesc = "on the \(days.joined(separator: ", "))"
                } else if dom.contains("-") {
                    let range = dom.split(separator: "-")
                    if range.count == 2 {
                        domDesc = "on the \(ordinal(String(range[0]))) through the \(ordinal(String(range[1])))"
                    } else {
                        domDesc = "on days \(dom)"
                    }
                } else {
                    domDesc = "on the \(ordinal(dom))"
                }
            }

            // When both dom and dow are specified, cron uses OR (union)
            if !domDesc.isEmpty && !dowDesc.isEmpty {
                when = "\(domDesc) and \(dowDesc)"
            } else if !dowDesc.isEmpty {
                when = dowDesc
            } else if !domDesc.isEmpty {
                when = domDesc
            }

            // Month
            if !monthWild {
                if let m = Int(month), m >= 1, m <= 12 {
                    let monthPart = "in \(monthNames[m])"
                    when = when.isEmpty ? monthPart : "\(when) \(monthPart)"
                }
            }
        }

        if when.isEmpty {
            return time
        }

        // Combine naturally: "Every minute" doesn't need a comma, but "At 9:00 AM" does
        if time.hasPrefix("Every") {
            return "\(time), \(when)"
        }
        return "\(time), \(when)"
    }

    private func loadCronList() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let result = try await RunbookCLI.shared.cronList()
                await MainActor.run {
                    output = result
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

        var entries: [ScheduleEntry] = []
        for line in lines.dropFirst() { // skip header
            // Format: "name  schedule  command" with variable whitespace
            // The schedule is 5 cron fields, so we need to parse carefully
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Split on 2+ spaces to get columns
            let parts = trimmed.components(separatedBy: "  ").filter { !$0.isEmpty }.map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2 else { continue }

            let name = parts[0]

            // The schedule is the 5 cron fields — find them after the name
            // Remove the name prefix, then extract 5 space-separated fields
            var remainder = trimmed
            if let nameRange = remainder.range(of: name) {
                remainder = String(remainder[nameRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            }

            let tokens = remainder.split(separator: " ").map(String.init)
            guard tokens.count >= 5 else { continue }

            let schedule = tokens[0...4].joined(separator: " ")
            let command = tokens.count > 5 ? tokens[5...].joined(separator: " ") : ""

            entries.append(ScheduleEntry(
                name: name,
                schedule: schedule,
                command: command,
                description: describeCron(schedule)
            ))
        }
        return entries
    }

    private func updateSchedule(name: String) {
        // Find the old schedule from the editing entry ID
        let oldSchedule = schedules.first { $0.id == editingName }?.schedule
        errorMessage = nil
        let newSched = editSchedule
        Task {
            do {
                if let old = oldSchedule {
                    _ = try await RunbookCLI.shared.cronRemove(name: name, schedule: old)
                }
                _ = try await RunbookCLI.shared.cronAdd(name: name, schedule: newSched)
                await MainActor.run { editingName = nil }
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

    private func ordinal(_ s: String) -> String {
        guard let n = Int(s) else { return s }
        let suffix: String
        if (11...13).contains(n % 100) {
            suffix = "th"
        } else {
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }

}


// Vertical turn pipe between rows — sits at the edge where rows meet
private struct TurnPipe: View {
    enum Direction { case rightDown, leftDown }
    let direction: Direction

    var body: some View {
        Canvas { context, size in
            let color = Color.secondary.opacity(0.4)
            let midX = size.width / 2
            let r: CGFloat = 6

            var path = Path()
            // Vertical line from top center down, curving at the bottom
            path.move(to: CGPoint(x: midX, y: 0))
            path.addLine(to: CGPoint(x: midX, y: size.height - r))

            if direction == .rightDown {
                // Curve to the left (next row goes R→L)
                path.addQuadCurve(
                    to: CGPoint(x: midX - r, y: size.height),
                    control: CGPoint(x: midX, y: size.height)
                )
                context.stroke(path, with: .color(color), lineWidth: 1.3)
                // Arrowhead pointing left
                var arrow = Path()
                let tip = CGPoint(x: midX - r, y: size.height)
                arrow.move(to: CGPoint(x: tip.x + 4, y: tip.y - 3))
                arrow.addLine(to: tip)
                arrow.addLine(to: CGPoint(x: tip.x + 4, y: tip.y + 3))
                context.stroke(arrow, with: .color(color), lineWidth: 1.5)
            } else {
                // Curve to the right (next row goes L→R)
                path.addQuadCurve(
                    to: CGPoint(x: midX + r, y: size.height),
                    control: CGPoint(x: midX, y: size.height)
                )
                context.stroke(path, with: .color(color), lineWidth: 1.3)
                // Arrowhead pointing right
                var arrow = Path()
                let tip = CGPoint(x: midX + r, y: size.height)
                arrow.move(to: CGPoint(x: tip.x - 4, y: tip.y - 3))
                arrow.addLine(to: tip)
                arrow.addLine(to: CGPoint(x: tip.x - 4, y: tip.y + 3))
                context.stroke(arrow, with: .color(color), lineWidth: 1.5)
            }
        }
    }
}

// Horizontal arrow connector between pills
private struct StepArrow: View {
    enum Direction { case left, right }
    let direction: Direction

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let lineColor = Color.secondary.opacity(0.35)

            // Line
            var line = Path()
            line.move(to: CGPoint(x: 2, y: midY))
            line.addLine(to: CGPoint(x: size.width - 2, y: midY))
            context.stroke(line, with: .color(lineColor), lineWidth: 1.2)

            // Arrowhead
            var arrow = Path()
            if direction == .right {
                arrow.move(to: CGPoint(x: size.width - 7, y: midY - 3.5))
                arrow.addLine(to: CGPoint(x: size.width - 2, y: midY))
                arrow.addLine(to: CGPoint(x: size.width - 7, y: midY + 3.5))
            } else {
                arrow.move(to: CGPoint(x: 7, y: midY - 3.5))
                arrow.addLine(to: CGPoint(x: 2, y: midY))
                arrow.addLine(to: CGPoint(x: 7, y: midY + 3.5))
            }
            context.stroke(arrow, with: .color(lineColor), lineWidth: 1.5)
        }
    }
}

// U-turn connector between rows — spans full width
private struct RowTurnConnector: View {
    enum Direction { case leftToRight, rightToLeft }
    let direction: Direction

    var body: some View {
        Canvas { context, size in
            let color = Color.secondary.opacity(0.35)
            let r: CGFloat = 8 // corner radius

            var path = Path()
            if direction == .rightToLeft {
                // Row ended at right, next row starts at right → curve on right side
                // From: top-right (end of L→R row) down and around to bottom-right (start of R→L row)
                let x = size.width - 4
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height / 2 - r))
                path.addQuadCurve(
                    to: CGPoint(x: x - r, y: size.height / 2),
                    control: CGPoint(x: x, y: size.height / 2)
                )
                path.addLine(to: CGPoint(x: x - r, y: size.height / 2))
                path.addLine(to: CGPoint(x: x - r, y: size.height / 2))
                // Continue down
                path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height - r))
                path.addQuadCurve(
                    to: CGPoint(x: x - r, y: size.height),
                    control: CGPoint(x: x, y: size.height)
                )
                context.stroke(path, with: .color(color), lineWidth: 1.2)
                // Arrowhead
                var arrow = Path()
                arrow.move(to: CGPoint(x: x - r + 4, y: size.height - 4))
                arrow.addLine(to: CGPoint(x: x - r, y: size.height))
                arrow.addLine(to: CGPoint(x: x - r - 4, y: size.height - 4))
                context.stroke(arrow, with: .color(color), lineWidth: 1.5)
            } else {
                // Row ended at left, next row starts at left → curve on left side
                let x: CGFloat = 4
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height - r))
                path.addQuadCurve(
                    to: CGPoint(x: x + r, y: size.height),
                    control: CGPoint(x: x, y: size.height)
                )
                context.stroke(path, with: .color(color), lineWidth: 1.2)
                // Arrowhead
                var arrow = Path()
                arrow.move(to: CGPoint(x: x + r - 4, y: size.height - 4))
                arrow.addLine(to: CGPoint(x: x + r, y: size.height))
                arrow.addLine(to: CGPoint(x: x + r + 4, y: size.height - 4))
                context.stroke(arrow, with: .color(color), lineWidth: 1.5)
            }
        }
    }
}

private extension CronView {
    func addSchedule() {
        errorMessage = nil
        Task {
            do {
                _ = try await RunbookCLI.shared.cronAdd(name: newName, schedule: newSchedule)
                await MainActor.run {
                    newName = ""
                    newSchedule = ""
                    showAdd = false
                }
                loadCronList()
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }
}
