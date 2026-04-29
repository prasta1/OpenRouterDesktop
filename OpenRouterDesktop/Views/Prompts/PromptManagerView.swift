import SwiftUI

struct PromptManagerView: View {
    @EnvironmentObject var promptLibrary: PromptLibraryViewModel
    @Environment(\.dismiss) var dismiss

    @State private var editing: PromptTemplate?
    @State private var creatingNew: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Prompt Library").font(.headline)
                Spacer()
                Button {
                    creatingNew = true
                } label: {
                    Label("New Prompt", systemImage: "plus")
                }
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            List {
                Section(PromptTemplate.Kind.systemPrompt.sectionTitle) {
                    ForEach(promptLibrary.systemPrompts) { row($0) }
                }
                Section(PromptTemplate.Kind.userSnippet.sectionTitle) {
                    ForEach(promptLibrary.snippets) { row($0) }
                }
            }
        }
        .frame(width: 580, height: 500)
        .sheet(item: $editing) { prompt in
            PromptEditView(initial: prompt) { updated in
                promptLibrary.update(updated)
            }
        }
        .sheet(isPresented: $creatingNew) {
            PromptEditView(initial: nil) { newPrompt in
                promptLibrary.add(newPrompt)
            }
        }
    }

    private func row(_ prompt: PromptTemplate) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(prompt.name).font(.system(size: 13, weight: .medium))
                Text(prompt.body)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button("Edit") { editing = prompt }
                .buttonStyle(.borderless)
            Button {
                promptLibrary.delete(id: prompt.id)
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

struct PromptEditView: View {
    let initial: PromptTemplate?
    var onSave: (PromptTemplate) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    @State private var promptBody: String = ""
    @State private var kind: PromptTemplate.Kind = .userSnippet

    private var isEditing: Bool { initial != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isEditing ? "Edit Prompt" : "New Prompt").font(.headline)

            HStack {
                Text("Name").frame(width: 60, alignment: .leading)
                TextField("Name", text: $name).textFieldStyle(.roundedBorder)
            }

            HStack {
                Text("Type").frame(width: 60, alignment: .leading)
                Picker("Type", selection: $kind) {
                    ForEach(PromptTemplate.Kind.allCases, id: \.self) { k in
                        Text(k.label).tag(k)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Text("Body")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            TextEditor(text: $promptBody)
                .font(.body)
                .frame(width: 480, height: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty, !promptBody.isEmpty else { return }
                    if let initial {
                        let updated = PromptTemplate(
                            id: initial.id,
                            name: trimmed,
                            body: promptBody,
                            kind: kind,
                            createdAt: initial.createdAt
                        )
                        onSave(updated)
                    } else {
                        onSave(PromptTemplate(name: trimmed, body: promptBody, kind: kind))
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || promptBody.isEmpty)
            }
        }
        .padding(20)
        .onAppear {
            if let initial {
                name = initial.name
                promptBody = initial.body
                kind = initial.kind
            }
        }
    }
}
