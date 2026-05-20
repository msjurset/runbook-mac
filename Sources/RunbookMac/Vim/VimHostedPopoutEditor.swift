import SwiftUI

/// CodePopoutEditor wrapped with a slim header (vim toolbar + close) and
/// a slash-suggestion pill. Used inside EditableConfigRow's popover,
/// which has no surrounding chrome of its own. Default = vim off.
struct VimHostedPopoutEditor: View {
    @Binding var text: String
    let language: CodeLanguage
    /// Called when the user clicks the explicit close button. The host
    /// popover's `.onDisappear { save() }` still drives the save path.
    var onClose: () -> Void

    @State private var vimHost = VimEditorHost()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Spacer()
                VimToolbarItem(controller: vimHost.vim)
                Button(action: onClose) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close (saves)")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            Divider()

            CodePopoutEditor(
                text: $text,
                language: language,
                vimEngine: vimHost.vim.engine,
                slashPrefix: $vimHost.slashPrefix,
                onSlashKeyEvent: { vimHost.handleSlashKey($0, text: $text) }
            )
            .vimSlashOverlay(vimHost)
        }
        .onAppear {
            // `:w` and `:wq` in the popout close it; the outer
            // .onDisappear handler invokes save() with the final text.
            vimHost.onSubmit = onClose
        }
    }
}
