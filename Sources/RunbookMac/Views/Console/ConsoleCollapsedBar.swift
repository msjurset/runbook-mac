import SwiftUI

/// Single-line status bar shown when the tray is collapsed. Click anywhere
/// to expand, or use the chevron button. Shows runbook name, live step
/// progress (last output line, truncated), elapsed time, and stop button.
struct ConsoleCollapsedBar: View {
    @Environment(RunSessionStore.self) private var store

    @State private var now = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        guard let session = store.current else { return AnyView(EmptyView()) }

        return AnyView(
            HStack(spacing: 10) {
                statusIcon(for: session)
                    .font(.callout)
                    .frame(width: 18)

                Text(session.runbookName)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)

                if session.dryRun {
                    Text("dry")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }

                Text("·")
                    .foregroundStyle(.tertiary)

                Text(lastLine(of: session))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(session.elapsed(now: now))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                SessionTabBar(compact: true)
                    .fixedSize(horizontal: false, vertical: true)

                if session.state == .running {
                    Button(role: .destructive) { store.cancelCurrent() } label: {
                        Image(systemName: "stop.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .help("Stop")
                } else {
                    Button { store.dismissCurrent() } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Dismiss")
                }

                Button { store.toggle() } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Expand console")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThickMaterial)
            .overlay(alignment: .top) { Divider() }
            .contentShape(Rectangle())
            .onTapGesture { store.toggle() }
            .onReceive(tick) { now = $0 }
        )
    }

    @ViewBuilder
    private func statusIcon(for session: RunSession) -> some View {
        switch session.state {
        case .running:
            ProgressView().controlSize(.small)
        case .succeeded:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
        case .cancelled:
            Image(systemName: "stop.circle.fill").foregroundStyle(.orange)
        }
    }

    /// Last non-blank output line for at-a-glance progress.
    private func lastLine(of session: RunSession) -> String {
        for line in session.output.reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { return trimmed }
        }
        return session.state == .running ? "starting…" : ""
    }
}
