import SwiftUI
import MarkdownUI
import AppKit

/// Replaces swift-markdown-ui's default code block with a layout that exposes
/// the language label and a "copy" button on every block.
struct CopyableCodeBlock: View {
    let configuration: CodeBlockConfiguration

    @State private var didCopy: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                if let language = configuration.language, !language.isEmpty {
                    Text(language)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: copy) {
                    HStack(spacing: 4) {
                        Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        Text(didCopy ? "Copied" : "Copy")
                    }
                    .font(.caption)
                    .foregroundColor(didCopy ? .green : .secondary)
                }
                .buttonStyle(.borderless)
                .help("Copy code block to clipboard")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08))

            configuration.label
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(configuration.content, forType: .string)
        didCopy = true
        // Reset back to "Copy" after a short delay so users see clear feedback.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            didCopy = false
        }
    }
}
