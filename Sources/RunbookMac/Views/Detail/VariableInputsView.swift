import SwiftUI

struct VariableInputsView: View {
    let variables: [VariableDef]
    @Binding var vars: [String: String]
    let isEditable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Variables")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(variables) { v in
                HStack {
                    Text(v.name)
                        .font(.body.monospaced())
                        .frame(width: 120, alignment: .trailing)
                    if !isEditable {
                        Text(vars[v.name] ?? v.default ?? "")
                            .font(.body.monospaced())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        FilterField(placeholder: v.default ?? "",
                                    text: binding(for: v.name))
                            .frame(maxWidth: .infinity)
                        if v.required == true {
                            Text("required")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { vars[key] ?? "" },
            set: { vars[key] = $0 }
        )
    }
}
