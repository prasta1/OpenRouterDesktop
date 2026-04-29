import Foundation

struct PromptTemplate: Identifiable, Codable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case systemPrompt
        case userSnippet

        var label: String {
            switch self {
            case .systemPrompt: return "System Prompt"
            case .userSnippet: return "Snippet"
            }
        }

        var sectionTitle: String {
            switch self {
            case .systemPrompt: return "System Prompts"
            case .userSnippet: return "Snippets"
            }
        }
    }

    let id: UUID
    var name: String
    var body: String
    var kind: Kind
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        body: String,
        kind: Kind,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.body = body
        self.kind = kind
        self.createdAt = createdAt
    }
}
