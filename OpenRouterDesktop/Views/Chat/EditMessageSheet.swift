import SwiftUI

struct EditMessageSheet: View {
    let originalContent: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit Message")
                .font(.headline)
            Text("Saving will remove every message after this one and re-generate the response.")
                .font(.caption)
                .foregroundColor(.secondary)
            TextEditor(text: $draft)
                .font(.body)
                .frame(width: 520, height: 220)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save & Regenerate") {
                    let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSave(draft)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .onAppear { draft = originalContent }
    }
}
