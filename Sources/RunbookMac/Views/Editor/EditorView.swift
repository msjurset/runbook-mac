import SwiftUI

struct EditorView: View {
    @Environment(RunbookStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let runbook: Runbook
    @State private var content: String = ""
    @State private var originalContent: String = ""
    @State private var errorMessage: String?
    @State private var showDiff = false

    var body: some View {
        VStack(spacing: 0) {
            if showDiff {
                DiffView(
                    original: originalContent,
                    modified: content,
                    onConfirm: { confirmSave() },
                    onCancel: { showDiff = false }
                )
            } else {
                editorContent
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            let yaml = store.readRawYAML(for: runbook) ?? ""
            content = yaml
            originalContent = yaml
        }
    }

    private var editorContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit: \(runbook.name)")
                    .font(.headline)
                Spacer()
                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding()

            Divider()

            CodeEditorView(text: $content)

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Validate") { validate() }
                Button("Save") { reviewChanges() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
    }

    private func validate() {
        guard let path = runbook.filePath else { return }
        Task {
            do {
                let result = try await RunbookCLI.shared.validate(nameOrPath: path)
                await MainActor.run { errorMessage = nil }
                _ = result
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    private func reviewChanges() {
        if content == originalContent {
            dismiss()
        } else {
            showDiff = true
        }
    }

    private func confirmSave() {
        guard let path = runbook.filePath else { return }
        let filename = (path as NSString).lastPathComponent
        do {
            try store.saveRaw(content, to: filename)
            store.loadAll()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showDiff = false
        }
    }
}

struct NewRunbookSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (String, String) throws -> Void

    @State private var selectedTemplate: RunbookTemplate = RunbookTemplate.templates[0]
    @State private var name = ""
    @State private var content = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Runbook")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            HStack(spacing: 16) {
                // Template picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Template")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    List(RunbookTemplate.templates, selection: $selectedTemplate) { tmpl in
                        VStack(alignment: .leading) {
                            Text(tmpl.name).fontWeight(.medium)
                            Text(tmpl.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(tmpl)
                        .padding(.vertical, 2)
                    }
                    .listStyle(.bordered)
                    .frame(width: 200)
                }

                // Editor
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Name")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("my-runbook", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                    CodeEditorView(text: $content)
                        .border(.quaternary)
                }
            }
            .padding()

            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") { create() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 700, minHeight: 500)
        .onChange(of: selectedTemplate) {
            content = selectedTemplate.content
            if name.isEmpty {
                name = selectedTemplate.id == "blank" ? "" : selectedTemplate.id
            }
        }
        .onAppear {
            content = selectedTemplate.content
        }
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Replace the name in the YAML content
        var yaml = content
        if let range = yaml.range(of: "name: .*", options: .regularExpression) {
            yaml.replaceSubrange(range, with: "name: \(trimmed)")
        }
        do {
            try onSave(trimmed, yaml)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
