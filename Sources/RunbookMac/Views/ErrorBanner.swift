import SwiftUI

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
            Spacer()
            Button("Dismiss") { onDismiss() }
                .font(.caption)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}
