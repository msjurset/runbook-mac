import SwiftUI

/// Bottom-docked tray that shows the current or most-recently-completed
/// runbook execution. Present across every sidebar section, non-modal, so
/// the user can keep navigating and editing while a run is in flight.
struct ConsoleTray: View {
    @Environment(RunSessionStore.self) private var store

    var body: some View {
        Group {
            if store.current == nil {
                EmptyView()
            } else if store.isExpanded {
                ConsoleExpandedView()
            } else {
                ConsoleCollapsedBar()
            }
        }
        .animation(.easeInOut(duration: 0.18), value: store.isExpanded)
        .animation(.easeInOut(duration: 0.18), value: store.current?.id)
    }
}
