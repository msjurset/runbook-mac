import SwiftUI

/// Full-height tray panel showing the current run's streaming output. The
/// header row is a session tab strip — each concurrent run gets one tab
/// flex-growing to fill the bar, with × on each to stop/dismiss. The output
/// toolbar surfaces Stop (while running) and Retry (when terminal) next to
/// Copy All so the tab itself never has to be destroyed to cancel.
struct ConsoleExpandedView: View {
    @Environment(RunSessionStore.self) private var store
    @Environment(RunbookStore.self) private var runbookStore

    var body: some View {
        guard let session = store.current else { return AnyView(EmptyView()) }

        // Non-writing binding — RunnerOutputView only reads.
        let outputBinding = Binding<[String]>(
            get: { store.current?.output ?? [] },
            set: { _ in }
        )

        return AnyView(
            VStack(spacing: 0) {
                Divider()

                // Tab strip — each session gets an equal share of the bar.
                HStack(spacing: 6) {
                    SessionTabBar(compact: false)
                        .frame(maxWidth: .infinity)
                    Button { store.toggle() } label: {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Collapse console")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

                Divider()

                RunnerOutputView(
                    runbookName: session.runbookName,
                    runStartedAt: session.startedAt,
                    output: outputBinding,
                    stopAction: session.state == .running
                        ? { store.cancel(sessionID: session.id) }
                        : nil,
                    retryAction: session.state.isTerminal
                        ? { dry in retry(session, dryRun: dry) }
                        : nil,
                    retryInitialDryRun: session.dryRun
                )
                .frame(height: 280)
            }
            .background(.ultraThickMaterial)
        )
    }

    /// Rerun the session's runbook in place with the dry-run flag chosen
    /// in the toolbar's Dry checkbox. Falls back silently if the runbook
    /// has been renamed or deleted.
    private func retry(_ session: RunSession, dryRun: Bool) {
        guard let runbook = runbookStore.runbooks.first(where: { $0.name == session.runbookName })
            ?? runbookStore.templates.first(where: { $0.name == session.runbookName })
        else { return }
        store.restart(sessionID: session.id, runbook: runbook, dryRun: dryRun)
    }
}
