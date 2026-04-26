import AppKit
import SwiftUI

/// Tab strip for switching between concurrent runbook sessions. Each tab
/// flex-grows to equally share the bar's width. The × on each tab stops
/// the run (if running) and removes the session from the store.
struct SessionTabBar: View {
    @Environment(RunSessionStore.self) private var store
    /// Compact = 1-line collapsed-bar use; renders smaller and drops elapsed/×
    /// details. Full = expanded-view use; renders full tab content.
    var compact: Bool = false

    @State private var now = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: compact ? 3 : 4) {
            ForEach(store.sessions) { session in
                tab(for: session)
                    .frame(maxWidth: .infinity)
            }
        }
        .onReceive(tick) { now = $0 }
    }

    @ViewBuilder
    private func tab(for session: RunSession) -> some View {
        let isActive = session.id == store.currentID

        Button {
            store.show(session.id)
        } label: {
            HStack(spacing: 6) {
                statusIcon(for: session)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        Text(session.runbookName)
                            .font(compact ? .caption : .callout.weight(isActive ? .semibold : .regular))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if !compact, session.dryRun {
                            Text("dry")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 0.5)
                                .background(.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                    if !compact, isActive {
                        Text(subtitle(for: session))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                if !compact {
                    Button {
                        close(session)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .padding(4)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help(session.state == .running ? "Stop and dismiss" : "Dismiss")
                }
            }
            .padding(.horizontal, compact ? 6 : 10)
            .padding(.vertical, compact ? 3 : 6)
            .background(
                RoundedRectangle(cornerRadius: compact ? 5 : 6)
                    .fill(isActive
                          ? Color.accentColor.opacity(0.18)
                          : Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 5 : 6)
                    .stroke(isActive ? Color.accentColor.opacity(0.45) : Color.clear,
                            lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: compact ? 5 : 6))
        }
        .buttonStyle(.plain)
        .help(tooltip(for: session))
    }

    /// × behavior: stop (if running) then remove the session from the store.
    private func close(_ session: RunSession) {
        if session.state == .running {
            store.cancel(sessionID: session.id)
        }
        // If we're removing the currently-shown session, step the focus
        // before we drop it so the tray doesn't blink through nil.
        if store.currentID == session.id {
            let nextID = nextSessionID(after: session.id)
            store.currentID = nextID
        }
        // Non-terminal sessions have to terminate before dismissCurrent will
        // remove them; set focus then schedule removal shortly after.
        if session.state == .running {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000)
                store.forceRemove(sessionID: session.id)
            }
        } else {
            store.forceRemove(sessionID: session.id)
        }
    }

    private func nextSessionID(after id: UUID) -> UUID? {
        guard let idx = store.sessions.firstIndex(where: { $0.id == id }) else { return nil }
        // Prefer the session to the left (earlier started, stays in view),
        // else the one to the right.
        if idx + 1 < store.sessions.count { return store.sessions[idx + 1].id }
        if idx > 0 { return store.sessions[idx - 1].id }
        return nil
    }

    @ViewBuilder
    private func statusIcon(for session: RunSession) -> some View {
        switch session.state {
        case .running:
            ProgressView()
                .controlSize(.mini)
        case .succeeded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.octagon.fill")
                .foregroundStyle(.red)
        case .cancelled:
            Image(systemName: "stop.circle.fill")
                .foregroundStyle(.orange)
        }
    }

    private func subtitle(for session: RunSession) -> String {
        switch session.state {
        case .running:        return "Running · \(session.elapsed(now: now))"
        case .succeeded:      return "Succeeded in \(session.elapsed())"
        case .failed(let m):  return "Failed · \(m)"
        case .cancelled:      return "Cancelled after \(session.elapsed())"
        }
    }

    private func tooltip(for session: RunSession) -> String {
        "\(session.runbookName) — \(subtitle(for: session))"
    }
}
