import SwiftUI
import AppKit
import VimEngine

/// Per-editor vim state. One instance is owned by each host view
/// (EditorView, NewRunbookSheet, EditableConfigRow's popout). Holds the
/// engine, mirrors its submode into a published badge string, and
/// rebroadcasts mode flips so the host can repaint without each call
/// site having to wire engine callbacks itself.
@Observable
@MainActor
final class VimController {
    var engine: VimEngine?
    var badge: String = "VIM:N"
    var showCheatsheet: Bool = false
    /// Called when vim's `:w` / `:wq` fires. Hosts wire this to their
    /// Save action. Read at submit time, so hosts can update it
    /// before or after activation.
    var onSubmit: (() -> Void)?

    var isActive: Bool { engine != nil }

    func toggle() {
        if engine == nil { activate() } else { deactivate() }
    }

    func activate() {
        guard engine == nil else { return }
        let e = VimEngine()
        let refresh: () -> Void = { [weak self, weak e] in
            Task { @MainActor in
                guard let self, let e else { return }
                self.badge = e.badge
            }
        }
        e.onSubmodeChanged = refresh
        e.onCommandBufferChanged = refresh
        e.onExit = { [weak self] in
            Task { @MainActor in self?.deactivate() }
        }
        e.onSubmit = { [weak self] in
            Task { @MainActor in self?.onSubmit?() }
        }
        badge = e.badge
        engine = e
    }

    func deactivate() {
        engine = nil
        badge = "VIM:N"
        showCheatsheet = false
    }
}

/// Toolbar item: a vim icon when off, or a badge pill (+cheatsheet
/// button) when on. Sized to match the surrounding caption controls.
struct VimToolbarItem: View {
    @Bindable var controller: VimController

    var body: some View {
        HStack(spacing: 4) {
            if controller.engine != nil {
                Button(action: { controller.showCheatsheet.toggle() }) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Vim command reference")
                .popover(isPresented: $controller.showCheatsheet, arrowEdge: .top) {
                    VimCheatsheetView()
                }
                badge
            } else {
                Button(action: { controller.activate() }) {
                    VimGlyph()
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Vim mode (off). Click — or type /vim — to enable.")
            }
        }
    }

    private var badge: some View {
        Button(action: { controller.deactivate() }) {
            HStack(spacing: 3) {
                Text(controller.badge)
                    .font(.caption2.bold())
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.3))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Vim mode. Click to exit, or :q / :wq in normal mode.")
    }
}

/// Combined host-side state for an editor that exposes vim mode + the
/// `/`-prefix slash dropdown. One instance per editor instance —
/// hosts own a `@State` of this and pass its slices through to the
/// editor's bindings.
///
/// Centralizes the four host responsibilities so each call site is one
/// `@State` declaration instead of three plus 25+ lines of slash-handler
/// boilerplate:
/// 1. The `VimController` (engine state + badge).
/// 2. The slash prefix + dropdown selection index.
/// 3. The slash-key navigation router (arrows / Enter / Esc / Space).
/// 4. The slash-command commit (delete the typed `/vim` from the buffer
///    and toggle vim).
@Observable
@MainActor
final class VimEditorHost {
    var vim = VimController()
    var slashPrefix: String = ""
    var slashIndex: Int = 0

    /// Hook for `:w` / `:wq`. Forwards through the underlying engine.
    var onSubmit: (() -> Void)? {
        get { vim.onSubmit }
        set { vim.onSubmit = newValue }
    }

    var isActive: Bool { vim.isActive }

    /// Clear all vim / slash state. Call from cancel + save handlers so
    /// the next entry into edit starts fresh.
    func reset() {
        vim.deactivate()
        slashPrefix = ""
        slashIndex = 0
    }

    /// Drop-in for `CodeEditorView.onSlashKeyEvent`. Needs the text
    /// binding so a Tab/Enter/Space commit can splice out the typed
    /// `/vim` prefix.
    func handleSlashKey(
        _ event: CodeEditorView.SuggestionKeyEvent,
        text: Binding<String>
    ) -> Bool {
        SlashKeyRouter(
            prefix: slashPrefix,
            selectedIndex: Binding(
                get: { self.slashIndex },
                set: { self.slashIndex = $0 }
            ),
            onCommit: { self.commit($0, text: text) },
            onCancel: { self.slashPrefix = "" }
        ).handle(event)
    }

    private func commit(_ command: SlashCommand, text: Binding<String>) {
        guard !slashPrefix.isEmpty,
              let range = text.wrappedValue.range(of: slashPrefix, options: .backwards) else {
            slashPrefix = ""
            return
        }
        switch command {
        case .mode:
            text.wrappedValue.replaceSubrange(range, with: "")
            vim.toggle()
        }
        slashPrefix = ""
    }
}

/// View modifier that wraps an editor in the slash-suggestion pill and
/// resets the selection index when the prefix changes. Pairs with
/// `VimEditorHost` — every host using vim mode applies this once and
/// the dropdown UX comes for free.
struct VimSlashOverlay: ViewModifier {
    @Bindable var host: VimEditorHost

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            content
            if !host.slashPrefix.isEmpty {
                SlashSuggestionView(
                    commands: SlashCommandRegistry.all,
                    filter: host.slashPrefix,
                    selectedIndex: $host.slashIndex
                )
            }
        }
        .onChange(of: host.slashPrefix) { _, _ in host.slashIndex = 0 }
    }
}

extension View {
    /// Attach the slash-suggestion pill + index-reset behavior. The
    /// underlying editor still needs the explicit `vimEngine`,
    /// `slashPrefix`, and `onSlashKeyEvent` bindings — this just wraps
    /// the visual + reactive bits.
    func vimSlashOverlay(_ host: VimEditorHost) -> some View {
        modifier(VimSlashOverlay(host: host))
    }
}

/// `:_` mark used as the vim toggle icon — the universal vim command-line
/// prompt. Rendered as styled text (heavy monospaced) so it stays crisp
/// at any size and recolors with `.foregroundStyle` like any other Text.
/// The negative baseline offset pulls the underscore up so the glyph
/// vertically centers in the surrounding button.
private struct VimGlyph: View {
    var body: some View {
        Text(":_")
            .font(.system(size: 14, weight: .heavy, design: .monospaced))
            .baselineOffset(-2)
            .tracking(-1)
    }
}

/// Slash-key navigation result. Returns true when the host fully
/// handled the event (and the editor should swallow it).
@MainActor
struct SlashKeyRouter {
    let prefix: String
    let selectedIndex: Binding<Int>
    let onCommit: (SlashCommand) -> Void
    let onCancel: () -> Void

    func handle(_ event: CodeEditorView.SuggestionKeyEvent) -> Bool {
        let items = SlashCommandRegistry.match(prefix: prefix)
        switch event {
        case .arrowDown:
            guard !items.isEmpty else { return false }
            selectedIndex.wrappedValue = min(selectedIndex.wrappedValue + 1, items.count - 1)
            return true
        case .arrowUp:
            guard !items.isEmpty else { return false }
            selectedIndex.wrappedValue = max(selectedIndex.wrappedValue - 1, 0)
            return true
        case .enter, .tab:
            guard !items.isEmpty else { return false }
            let idx = min(max(0, selectedIndex.wrappedValue), items.count - 1)
            onCommit(items[idx])
            return true
        case .escape:
            onCancel()
            return true
        case .space:
            // Space commits only on an exact case-insensitive match.
            // Otherwise let the space fall through — typing past the
            // command name ends the slash context naturally.
            if let cmd = SlashCommandRegistry.exactMatch(prefix: prefix) {
                onCommit(cmd)
                return true
            }
            return false
        }
    }
}
