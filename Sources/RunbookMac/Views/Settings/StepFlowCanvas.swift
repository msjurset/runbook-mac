import SwiftUI

/// Draws a serpentine step pipeline entirely in Canvas for pixel-perfect layout.
struct StepFlowCanvas: View {
    let steps: [Step]
    let colorScheme: ColorScheme
    var runbookName: String? = nil

    @Environment(RunbookStore.self) private var store

    // Layout constants
    private let pillHeight: CGFloat = 24
    private let pillPadding: CGFloat = 12
    private let arrowLength: CGFloat = 20
    private let rowGap: CGFloat = 4
    private let fontSize: CGFloat = 11
    private let turnRadius: CGFloat = 10

    @State private var computedHeight: CGFloat = 30
    @State private var selectedPillID: String?
    @State private var selectedLogPillID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                let layout = computeLayout(width: geo.size.width)
                ZStack(alignment: .topLeading) {
                    Canvas { context, size in
                        drawPipeline(context: context, layout: layout, size: size)
                    }

                    // Click hit-test rects, anchored at each pill's exact rect.
                    // .popover BEFORE .position so it anchors to the pill-sized frame,
                    // not the parent ZStack.
                    //
                    // SwiftUI's onTapGesture(count:2) + onTapGesture(count:1)
                    // pair handles double-vs-single discrimination natively.
                    // Right-click is handled by a backing NSView since SwiftUI
                    // does not expose a right-mouse gesture on macOS.
                    ForEach(Array(layout.pills.enumerated()), id: \.offset) { idx, pill in
                        let pillID = "\(idx)|\(pill.step.name)"
                        ZStack {
                            // SwiftUI tap layer (left + double click). Sits BELOW the
                            // right-click catcher so left clicks reach it.
                            Color.clear
                                .contentShape(Rectangle())
                                .onHover { inside in
                                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                }
                                .onTapGesture(count: 2) {
                                    selectedPillID = nil
                                    selectedLogPillID = nil
                                    guard let name = runbookName else { return }
                                    NotificationCenter.default.post(
                                        name: .runbookNavigateToStep,
                                        object: nil,
                                        userInfo: [
                                            "runbookName": name,
                                            "stepName": pill.step.name
                                        ]
                                    )
                                }
                                .onTapGesture(count: 1) {
                                    selectedLogPillID = nil
                                    selectedPillID = (selectedPillID == pillID) ? nil : pillID
                                }
                            // Right-click catcher on TOP. Its hitTest returns nil for
                            // non-right events so left clicks fall through to the
                            // SwiftUI layer beneath. Right-clicks land here.
                            RightClickCatcher {
                                selectedPillID = nil
                                selectedLogPillID = (selectedLogPillID == pillID) ? nil : pillID
                            }
                        }
                        .frame(width: pill.rect.width, height: pill.rect.height)
                        .popover(isPresented: Binding(
                            get: { selectedPillID == pillID },
                            set: { if !$0 && selectedPillID == pillID { selectedPillID = nil } }
                        ), arrowEdge: .bottom) {
                            StepFlyoutView(
                                step: pill.step,
                                accent: pillBarColor(pill.step),
                                onOpenInDetail: {
                                    selectedPillID = nil
                                    selectedLogPillID = nil
                                    guard let name = runbookName else { return }
                                    NotificationCenter.default.post(
                                        name: .runbookNavigateToStep,
                                        object: nil,
                                        userInfo: [
                                            "runbookName": name,
                                            "stepName": pill.step.name
                                        ]
                                    )
                                }
                            )
                        }
                        .popover(isPresented: Binding(
                            get: { selectedLogPillID == pillID },
                            set: { if !$0 && selectedLogPillID == pillID { selectedLogPillID = nil } }
                        ), arrowEdge: .bottom) {
                            StepLogFlyoutView(
                                step: pill.step,
                                accent: pillBarColor(pill.step),
                                lastRecord: lastHistoryRecord(),
                                lastStepRecord: lastStepRecord(named: pill.step.name)
                            )
                        }
                        .position(x: pill.rect.midX, y: pill.rect.midY)
                    }
                }
                .onAppear { computedHeight = layout.totalHeight }
                .onChange(of: geo.size.width) { _, _ in
                    computedHeight = computeLayout(width: geo.size.width).totalHeight
                }
            }
            .frame(height: computedHeight)

            StepFlowLegend()
        }
    }

    // MARK: - Layout computation

    private struct PillLayout {
        var step: Step
        var rect: CGRect
        var row: Int
        var reversed: Bool
    }

    private struct PipelineLayout {
        var pills: [PillLayout]
        var rows: Int
        var totalHeight: CGFloat
    }

    private func measurePill(_ step: Step) -> CGFloat {
        let name = abbreviate(step.name, max: 22)
        // Approximate: 7pt per char + padding + color bar
        return CGFloat(name.count) * 7.0 + pillPadding * 2 + 8
    }

    private func computeLayout(width: CGFloat) -> PipelineLayout {
        guard !steps.isEmpty else {
            return PipelineLayout(pills: [], rows: 0, totalHeight: 0)
        }

        var pills: [PillLayout] = []
        var row = 0
        var x: CGFloat = 0
        let availableWidth = width

        // Assign pills to rows
        var rowAssignments: [[Int]] = [[]] // indices into pills

        for (i, step) in steps.enumerated() {
            let pillW = measurePill(step)
            let needed = x > 0 ? pillW + arrowLength : pillW

            if x + needed > availableWidth && x > 0 {
                row += 1
                x = 0
                rowAssignments.append([])
            }

            let pill = PillLayout(
                step: step,
                rect: .zero, // computed below
                row: row,
                reversed: row % 2 == 1
            )
            pills.append(pill)
            rowAssignments[row].append(i)
            x += needed
        }

        // Now compute actual positions with serpentine
        let totalRows = row + 1
        let normalGap = rowGap + turnRadius  // gap when side-exit turn
        let bottomExitGap = rowGap + turnRadius + 14  // extra space for bottom-exit turns

        // First pass: position pills and detect which transitions need extra space
        var rowYPositions: [CGFloat] = [0]
        for rowIdx in 1..<totalRows {
            let prevIndices = rowAssignments[rowIdx - 1]
            let currIndices = rowAssignments[rowIdx]
            guard let lastPillIdx = prevIndices.last, let nextPillIdx = currIndices.first else {
                rowYPositions.append(rowYPositions.last! + pillHeight + normalGap)
                continue
            }

            // Check if this turn will be a bottom-exit
            // We need the source pill rect and target center — estimate them
            let prevReversed = (rowIdx - 1) % 2 == 1
            let sourcePillW = measurePill(pills[lastPillIdx].step)
            let nextReversed = rowIdx % 2 == 1

            // Estimate source pill X range
            var prevX: CGFloat = 0
            for (j, idx) in prevIndices.enumerated() {
                let pw = measurePill(pills[idx].step)
                if idx == lastPillIdx {
                    if prevReversed {
                        // Source pill is at the left end of the R→L row
                        // Its minX is prevX (after subtracting)
                    }
                    break
                }
                prevX += measurePill(pills[idx].step) + arrowLength
            }

            // Simpler: estimate target center and check overlap with source pill width
            // For now, use a heuristic: if rows have very different item counts, likely needs bottom-exit
            // Actually, let's just use extra gap for ALL transitions — it's only 14px more
            // and it makes the flow cleaner
            let gap = bottomExitGap
            rowYPositions.append(rowYPositions.last! + pillHeight + gap)
        }

        for rowIdx in 0..<totalRows {
            let reversed = rowIdx % 2 == 1
            let indices = rowAssignments[rowIdx]
            let y = rowYPositions[rowIdx]

            var cx: CGFloat
            if reversed {
                cx = availableWidth
            } else {
                cx = 0
            }

            for (j, pillIdx) in indices.enumerated() {
                let pillW = measurePill(pills[pillIdx].step)

                if reversed {
                    if j > 0 { cx -= arrowLength }
                    cx -= pillW
                    pills[pillIdx].rect = CGRect(x: cx, y: y, width: pillW, height: pillHeight)
                } else {
                    if j > 0 { cx += arrowLength }
                    pills[pillIdx].rect = CGRect(x: cx, y: y, width: pillW, height: pillHeight)
                    cx += pillW
                }
            }
        }

        let totalHeight = (rowYPositions.last ?? 0) + pillHeight + 12

        return PipelineLayout(pills: pills, rows: totalRows, totalHeight: totalHeight)
    }

    // MARK: - Drawing

    private func drawPipeline(context: GraphicsContext, layout: PipelineLayout, size: CGSize) {
        let lineColor = colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.35)

        // Draw pills FIRST (bottom layer)
        for pill in layout.pills {
            drawPill(context: context, pill: pill)
        }

        // Draw arrows ON TOP so arrowheads aren't hidden behind pills
        for (i, pill) in layout.pills.enumerated() {
            if i < layout.pills.count - 1 {
                let next = layout.pills[i + 1]

                if pill.row == next.row {
                    // Same row: horizontal arrow — start/end at pill edges
                    let fromX = pill.reversed ? pill.rect.minX : pill.rect.maxX
                    let toX = next.reversed ? next.rect.maxX : next.rect.minX
                    let y = pill.rect.midY

                    drawArrow(context: context, from: CGPoint(x: fromX, y: y), to: CGPoint(x: toX, y: y), color: lineColor)
                } else {
                    // Different row: serpentine turn
                    // From: exit side of current pill
                    let fromX = pill.reversed ? pill.rect.minX : pill.rect.maxX
                    let fromY = pill.rect.midY
                    // To: the FLOW-ENTRY side of next pill (opposite of where between-pill arrows connect)
                    // For R→L row: flow enters from left side of pill
                    // For L→R row: flow enters from right side of pill... wait, no:
                    // Actually: enter the pill from the side the between-pill arrows come FROM
                    // R→L row: arrows go right-to-left, so first pill receives from its LEFT
                    // L→R row: arrows go left-to-right, so first pill receives from its RIGHT... no
                    // Simpler: the turn enters the pill from the SAME side as the edge
                    // But we want it on the opposite side. Let's make it wrap around:
                    let toY = next.rect.midY

                    let edgeX: CGFloat
                    if !pill.reversed {
                        edgeX = min(size.width - 4, max(pill.rect.maxX, next.rect.maxX) + 14)
                    } else {
                        edgeX = max(4, min(pill.rect.minX, next.rect.minX) - 14)
                    }

                    // Connect to the TOP CENTER of the next pill
                    let entryPoint = CGPoint(x: next.rect.midX, y: next.rect.minY)

                    drawTurnArrow(context: context,
                                  from: CGPoint(x: fromX, y: fromY),
                                  sourcePillRect: pill.rect,
                                  edge: CGPoint(x: edgeX, y: fromY),
                                  to: entryPoint,
                                  color: lineColor)
                }
            }
        }
    }

    private func drawPill(context: GraphicsContext, pill: PillLayout) {
        let rect = pill.rect
        let cornerRadius: CGFloat = 6
        let bgColor = pillBgColor(pill.step)
        let borderColor = pillBorderColor(pill.step)
        let barColor = pillBarColor(pill.step)

        // Background
        let path = RoundedRectangle(cornerRadius: cornerRadius).path(in: rect)
        context.fill(path, with: .color(bgColor))
        context.stroke(path, with: .color(borderColor), lineWidth: 0.8)

        // Color bar on left
        let barRect = CGRect(x: rect.minX + 3, y: rect.minY + 4, width: 3, height: rect.height - 8)
        context.fill(RoundedRectangle(cornerRadius: 1.5).path(in: barRect), with: .color(barColor))

        // Label
        let name = abbreviate(pill.step.name, max: 22)
        let textColor = colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.75)
        let text = Text(name).font(.system(size: fontSize, weight: .medium))
        context.draw(text, at: CGPoint(x: rect.midX + 3, y: rect.midY), anchor: .center)
    }

    private func drawArrow(context: GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        let dir: ArrowDir = to.x > from.x ? .right : .left
        let headLen: CGFloat = 10

        var path = Path()
        path.move(to: from)
        let lineEnd: CGPoint
        switch dir {
        case .right: lineEnd = CGPoint(x: to.x - headLen, y: to.y)
        case .left: lineEnd = CGPoint(x: to.x + headLen, y: to.y)
        }
        path.addLine(to: lineEnd)
        context.stroke(path, with: .color(color), lineWidth: 1.3)

        let headColor = colorScheme == .dark ? Color.white.opacity(0.85) : Color.black.opacity(0.7)
        drawArrowhead(context: context, at: to, direction: dir, color: headColor)
    }

    private enum ArrowDir { case left, right }

    private func drawArrowhead(context: GraphicsContext, at point: CGPoint, direction: ArrowDir, color: Color) {
        let len: CGFloat = 10
        let width: CGFloat = 6
        var head = Path()
        switch direction {
        case .right:
            head.move(to: CGPoint(x: point.x - len, y: point.y - width))
            head.addLine(to: point)
            head.addLine(to: CGPoint(x: point.x - len, y: point.y + width))
            head.closeSubpath()
        case .left:
            head.move(to: CGPoint(x: point.x + len, y: point.y - width))
            head.addLine(to: point)
            head.addLine(to: CGPoint(x: point.x + len, y: point.y + width))
            head.closeSubpath()
        }
        context.fill(head, with: .color(color))
    }

    private func drawTurnArrow(context: GraphicsContext, from: CGPoint, sourcePillRect: CGRect, edge: CGPoint, to: CGPoint, color: Color) {
        // to = top center of the next pill
        let r: CGFloat = 6
        let headLen: CGFloat = 10
        let headColor = colorScheme == .dark ? Color.white.opacity(0.85) : Color.black.opacity(0.7)

        // If target center X is INSIDE the source pill's left/right borders,
        // exit from BOTTOM of source pill (straight down).
        // Otherwise, exit from the SIDE (horizontal then curve down).
        let sourceOverlapsTarget = to.x >= sourcePillRect.minX && to.x <= sourcePillRect.maxX

        var path = Path()

        if sourceOverlapsTarget {
            // Exit from bottom center of source pill, go straight down
            let exitPoint = CGPoint(x: sourcePillRect.midX, y: sourcePillRect.maxY)
            path.move(to: exitPoint)
            path.addLine(to: CGPoint(x: exitPoint.x, y: to.y - headLen))

            // If target X is different, add a curve to reach it
            if abs(exitPoint.x - to.x) > r * 2 {
                // Go down partway, curve horizontal, then down to target
                let midY = (exitPoint.y + to.y - headLen) / 2
                path = Path()
                path.move(to: exitPoint)
                path.addLine(to: CGPoint(x: exitPoint.x, y: midY - r))
                if to.x > exitPoint.x {
                    path.addQuadCurve(to: CGPoint(x: exitPoint.x + r, y: midY), control: CGPoint(x: exitPoint.x, y: midY))
                    path.addLine(to: CGPoint(x: to.x - r, y: midY))
                    path.addQuadCurve(to: CGPoint(x: to.x, y: midY + r), control: CGPoint(x: to.x, y: midY))
                } else {
                    path.addQuadCurve(to: CGPoint(x: exitPoint.x - r, y: midY), control: CGPoint(x: exitPoint.x, y: midY))
                    path.addLine(to: CGPoint(x: to.x + r, y: midY))
                    path.addQuadCurve(to: CGPoint(x: to.x, y: midY + r), control: CGPoint(x: to.x, y: midY))
                }
                path.addLine(to: CGPoint(x: to.x, y: to.y - headLen))
            }
        } else {
            // Normal case: horizontal toward target X, curve, then straight down
            path.move(to: from)
            let curveX = to.x + (from.x > to.x ? r : -r)
            path.addLine(to: CGPoint(x: curveX, y: from.y))

            path.addQuadCurve(
                to: CGPoint(x: to.x, y: from.y + r),
                control: CGPoint(x: to.x, y: from.y)
            )
            path.addLine(to: CGPoint(x: to.x, y: to.y - headLen))
        }

        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))

        // Downward arrowhead into pill top
        var head = Path()
        head.move(to: CGPoint(x: to.x - 6, y: to.y - headLen))
        head.addLine(to: to)
        head.addLine(to: CGPoint(x: to.x + 6, y: to.y - headLen))
        head.closeSubpath()
        context.fill(head, with: .color(headColor))
    }

    // MARK: - Colors

    private func pillBgColor(_ step: Step) -> Color {
        let isDark = colorScheme == .dark
        if step.confirm != nil { return isDark ? Color(red: 0.2, green: 0.15, blue: 0.08) : Color(red: 1, green: 0.95, blue: 0.88) }
        switch step.type {
        case "ssh": return isDark ? Color(red: 0.08, green: 0.18, blue: 0.2) : Color(red: 0.88, green: 0.96, blue: 0.96)
        case "http": return isDark ? Color(red: 0.08, green: 0.2, blue: 0.1) : Color(red: 0.88, green: 0.97, blue: 0.88)
        default: return isDark ? Color(red: 0.08, green: 0.12, blue: 0.22) : Color(red: 0.88, green: 0.92, blue: 0.98)
        }
    }

    private func pillBorderColor(_ step: Step) -> Color {
        let isDark = colorScheme == .dark
        if step.confirm != nil { return isDark ? Color.orange.opacity(0.4) : Color.orange.opacity(0.4) }
        switch step.type {
        case "ssh": return isDark ? Color.teal.opacity(0.4) : Color.teal.opacity(0.4)
        case "http": return isDark ? Color.green.opacity(0.4) : Color.green.opacity(0.4)
        default: return isDark ? Color.blue.opacity(0.3) : Color.blue.opacity(0.3)
        }
    }

    private func pillBarColor(_ step: Step) -> Color {
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

    // MARK: - History lookup

    private func lastHistoryRecord() -> HistoryRecord? {
        guard let name = runbookName else { return nil }
        return store.history(for: name).first
    }

    private func lastStepRecord(named: String) -> StepRecord? {
        lastHistoryRecord()?.steps.first { $0.name == named }
    }
}

extension Notification.Name {
    /// Fired by the Schedules chart when the user double-clicks a step.
    /// ContentView consumes this to switch tabs and select the runbook.
    static let runbookNavigateToStep = Notification.Name("runbookNavigateToStep")
    /// Fired by ContentView ~150ms after handling `runbookNavigateToStep`,
    /// once the RunbookDetailView has had time to mount. RunbookDetailView
    /// consumes this to expand and scroll to the target step.
    static let runbookExpandStep = Notification.Name("runbookExpandStep")
}

// MARK: - Right-click only catcher
//
// The `hitTest` override only "claims" hits when the in-flight event is a
// right-mouse-down, so left-clicks fall through to the SwiftUI tap gestures
// stacked on top. Without this, the NSView would swallow all clicks.

private struct RightClickCatcher: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> NSView {
        let v = RightClickView()
        v.action = action
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? RightClickView)?.action = action
    }

    private final class RightClickView: NSView {
        var action: (() -> Void)?

        override func hitTest(_ point: NSPoint) -> NSView? {
            if let event = NSApp.currentEvent, event.type == .rightMouseDown {
                return self
            }
            return nil
        }

        override func rightMouseDown(with event: NSEvent) {
            action?()
        }
    }
}

// MARK: - Legend

struct StepFlowLegend: View {
    private struct Item: Identifiable {
        let id: String
        let color: Color
        let label: String
    }
    private let items: [Item] = [
        Item(id: "shell", color: .blue, label: "shell"),
        Item(id: "ssh", color: .teal, label: "ssh"),
        Item(id: "http", color: .green, label: "http"),
        Item(id: "confirm", color: .orange, label: "confirm"),
    ]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items) { item in
                HStack(spacing: 4) {
                    Capsule()
                        .fill(item.color)
                        .frame(width: 10, height: 4)
                    Text(item.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text("· click a step for details")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Click flyout

private struct StepFlyoutView: View {
    let step: Step
    let accent: Color
    /// Fired by the navigate icon and the code block's double-click. The parent
    /// dismisses the popover and posts `runbookNavigateToStep` so the sidebar
    /// switches to Runbooks and the runbook detail view scrolls to + expands
    /// the matching step.
    let onOpenInDetail: () -> Void

    private var typeLabel: String {
        if step.confirm != nil { return "confirm" }
        return step.type ?? "shell"
    }

    private var commandText: String? {
        if let s = step.shell?.command, !s.isEmpty { return s }
        if let s = step.ssh?.command, !s.isEmpty { return s }
        if let s = step.http?.body, !s.isEmpty { return s }
        return nil
    }

    /// Bash for shell/ssh commands, JSON if the http body parses as JSON,
    /// plain otherwise.
    private var commandLanguage: CodeLanguage {
        if step.shell != nil || step.ssh != nil { return .bash }
        if let body = step.http?.body {
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") { return .json }
        }
        return .plain
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(accent).frame(width: 8, height: 8)
                Text(step.name).font(.headline)
                Spacer(minLength: 0)
                Text(typeLabel)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(accent.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(accent)
            }

            if let host = step.ssh?.host {
                row(label: "host", value: host)
            }
            if let url = step.http?.url {
                row(label: "url", value: url)
            }
            if let method = step.http?.method, !method.isEmpty {
                row(label: "method", value: method)
            }
            if let cond = step.condition, !cond.isEmpty {
                row(label: "if", value: cond)
            }
            if let cap = step.capture, !cap.isEmpty {
                row(label: "capture", value: cap)
            }
            if let oe = step.on_error, !oe.isEmpty {
                row(label: "on_error", value: oe)
            }
            if let t = step.timeout, !t.isEmpty {
                row(label: "timeout", value: t)
            }
            if let r = step.retries {
                row(label: "retries", value: String(r))
            }
            if step.parallel == true {
                row(label: "parallel", value: "true")
            }
            if let confirm = step.confirm, !confirm.isEmpty {
                row(label: "confirm", value: confirm)
            }

            if let cmd = commandText {
                Divider()
                // Navigate icon ABOVE the scroll area so it stays anchored —
                // the user explicitly asked for it to not scroll out of view.
                HStack(spacing: 6) {
                    Spacer(minLength: 0)
                    Button {
                        onOpenInDetail()
                    } label: {
                        Image(systemName: "arrow.up.forward")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                    .help("Open step in runbook detail")
                }
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    CodeBlockView(source: cmd, language: commandLanguage, wrapsLines: false)
                }
                .frame(maxHeight: 320)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { onOpenInDetail() }
                .help("Double-click to open in runbook detail")
            }
        }
        .padding(10)
        .frame(minWidth: 280, idealWidth: 420, maxWidth: 560, alignment: .leading)
    }

    @ViewBuilder
    private func row(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)
            Text(value)
                .font(.callout)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Step log extractor
//
// The runbook CLI's log format separates runs with `--- run: <ts> ---` and
// each step with `▸ Step N: <name>` followed by indented body lines (most
// prefixed with `│ `) and a result line (`✓ done` / `✗ failed` / `⊘ skipped`).
// We grab the LAST run in the file (matches HistoryRecord.first) and extract
// the slice for the requested step name.

// MARK: - Right-click log flyout

private struct StepLogFlyoutView: View {
    let step: Step
    let accent: Color
    let lastRecord: HistoryRecord?
    let lastStepRecord: StepRecord?

    @State private var stepLogText: String?
    @State private var stepLogLoaded = false
    @State private var showLogSheet = false
    @State private var justCopied = false

    private var statusColor: Color {
        switch (lastStepRecord?.status ?? "").lowercased() {
        case "success", "succeeded", "passed": return .green
        case "failed", "error": return .red
        case "skipped": return .gray
        default: return .secondary
        }
    }

    private var statusIcon: String {
        switch (lastStepRecord?.status ?? "").lowercased() {
        case "success", "succeeded", "passed": return "checkmark.circle.fill"
        case "failed", "error": return "xmark.circle.fill"
        case "skipped": return "minus.circle.fill"
        default: return "questionmark.circle.fill"
        }
    }

    private var logURL: URL? {
        guard let rec = lastRecord else { return nil }
        return StepLogExtractor.findLogURL(for: rec)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(accent).frame(width: 8, height: 8)
                Text(step.name).font(.headline)
                Spacer(minLength: 0)
                Text("last run").font(.caption).foregroundStyle(.tertiary)
            }

            if let record = lastRecord, let stepRec = lastStepRecord {
                HStack(spacing: 6) {
                    Image(systemName: statusIcon).foregroundStyle(statusColor)
                    Text(stepRec.status.capitalized).font(.callout).foregroundStyle(statusColor)
                    Text("·").foregroundStyle(.tertiary)
                    Text(stepRec.duration).font(.callout.monospacedDigit())
                    Text("·").foregroundStyle(.tertiary)
                    Text(record.formattedDate).font(.caption).foregroundStyle(.secondary)
                }

                if let err = stepRec.error, !err.isEmpty {
                    Divider()
                    Text("Error").font(.caption.bold()).foregroundStyle(.red)
                    Text(err)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Inline step output from the actual log file
                Divider()
                if !stepLogLoaded {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Loading step output…")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else if let text = stepLogText, !text.isEmpty {
                    Text("Output").font(.caption.bold()).foregroundStyle(.secondary)
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(Array(text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()), id: \.offset) { _, line in
                                let str = String(line)
                                let highlight = OutputHighlighter.color(for: str)
                                let attr = OutputHighlighter.attributedLine(for: str, baseColor: highlight.color)
                                let hasLink = attr.runs.contains { $0.link != nil }
                                Text(attr)
                                    .font(.system(size: 11, design: .monospaced))
                                    .fontWeight(highlight.bold ? .bold : .regular)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .pointerStyle(hasLink ? .link : nil)
                            }
                        }
                        .padding(8)
                    }
                    .frame(height: 220)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.08))
                    )
                    .overlay(alignment: .topTrailing) {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(text, forType: .string)
                            withAnimation(.easeInOut(duration: 0.15)) { justCopied = true }
                            Task {
                                try? await Task.sleep(nanoseconds: 1_500_000_000)
                                withAnimation(.easeInOut(duration: 0.15)) { justCopied = false }
                            }
                        } label: {
                            Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                                .font(.caption2)
                                .foregroundStyle(justCopied ? Color.green : .secondary)
                                .padding(4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(.background.opacity(0.6))
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                        .help(justCopied ? "Copied" : "Copy step log to clipboard")
                    }
                } else {
                    Text("No output captured for this step.")
                        .font(.caption).foregroundStyle(.tertiary)
                }

                if let url = logURL {
                    HStack {
                        Text(url.lastPathComponent)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button("Open Log") { showLogSheet = true }
                            .controlSize(.small)
                    }
                } else {
                    Text("No log file recorded for this run.")
                        .font(.caption).foregroundStyle(.tertiary)
                }
            } else if lastRecord == nil {
                Text("No recent runs for this runbook.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                Text("This step did not appear in the last run.")
                    .font(.callout).foregroundStyle(.secondary)
                if logURL != nil {
                    HStack {
                        Spacer()
                        Button("Open Last Log") { showLogSheet = true }
                            .controlSize(.small)
                    }
                }
            }
        }
        .padding(10)
        .frame(minWidth: 320, idealWidth: 480, maxWidth: 640, alignment: .leading)
        .sheet(isPresented: $showLogSheet) {
            if let url = logURL {
                LogViewerSheet(url: url, matchDate: lastRecord?.startedDate)
            }
        }
        .task(id: step.name) {
            stepLogLoaded = false
            stepLogText = nil
            guard let url = logURL else {
                stepLogLoaded = true
                return
            }
            let name = step.name
            let extracted: String? = await Task.detached(priority: .userInitiated) {
                StepLogExtractor.extractStepLines(logURL: url, stepName: name)
            }.value
            stepLogText = extracted
            stepLogLoaded = true
        }
    }
}
