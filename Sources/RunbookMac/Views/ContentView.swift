import SwiftUI

enum SidebarItem: Hashable {
    case runbooks
    case history
    case cron
    case pull
}

struct ContentView: View {
    @Environment(RunbookStore.self) private var store
    @State private var sidebarSelection: SidebarItem? = .runbooks
    @State private var selectedRunbook: Runbook?
    @State private var showNewRunbook = false
    @State private var showQuickJump = false

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selection: $sidebarSelection,
                showNewRunbook: $showNewRunbook
            )
        } detail: {
            switch sidebarSelection {
            case .runbooks:
                RunbookBrowserView(selectedRunbook: $selectedRunbook)
            case .history:
                HistoryListView()
                    .accessibilityIdentifier("detail.history")
            case .cron:
                CronView()
                    .accessibilityIdentifier("detail.schedules")
            case .pull:
                PullView()
                    .accessibilityIdentifier("detail.repositories")
            case nil:
                ContentUnavailableView(
                    "Select a Section",
                    systemImage: "sidebar.left",
                    description: Text("Choose a section from the sidebar.")
                )
                .accessibilityIdentifier("detail.empty")
            }
        }
        .sheet(isPresented: $showNewRunbook) {
            NewRunbookSheet { name, content in
                try store.saveRaw(content, to: "\(name).yaml")
                store.loadAll()
            }
        }
        .sheet(isPresented: $showQuickJump) {
            QuickJumpSheet(selectedRunbook: $selectedRunbook, sidebarSelection: $sidebarSelection)
        }
        .onChange(of: sidebarSelection) {
            if sidebarSelection != .runbooks {
                selectedRunbook = nil
            }
        }
        .onAppear {
            store.loadAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: .runbookNavigateToStep)) { note in
            guard let info = note.userInfo,
                  let name = info["runbookName"] as? String,
                  let book = store.runbooks.first(where: { $0.name == name }) else { return }
            sidebarSelection = .runbooks
            selectedRunbook = book
            // Re-post once RunbookDetailView has had time to mount so its
            // listener actually receives it.
            if let stepName = info["stepName"] as? String {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    NotificationCenter.default.post(
                        name: .runbookExpandStep,
                        object: nil,
                        userInfo: ["runbookName": name, "stepName": stepName]
                    )
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ConsoleTray()
        }
        .frame(minWidth: 900, minHeight: 500)
        .focusedValue(\.sidebarSelection, $sidebarSelection)
        .focusedValue(\.showQuickJump, $showQuickJump)
    }
}

// Focus values to pass bindings up to the menu bar commands
struct SidebarSelectionKey: FocusedValueKey {
    typealias Value = Binding<SidebarItem?>
}

struct ShowQuickJumpKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var sidebarSelection: Binding<SidebarItem?>? {
        get { self[SidebarSelectionKey.self] }
        set { self[SidebarSelectionKey.self] = newValue }
    }
    var showQuickJump: Binding<Bool>? {
        get { self[ShowQuickJumpKey.self] }
        set { self[ShowQuickJumpKey.self] = newValue }
    }
}
