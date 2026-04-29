import Foundation

struct Conversation: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var folderID: UUID?
    var messages: [Message]
    let createdAt: Date
    var updatedAt: Date
    var modelID: String?
    var systemPrompt: String?
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        name: String = "New Chat",
        folderID: UUID? = nil,
        messages: [Message] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        modelID: String? = nil,
        systemPrompt: String? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.name = name
        self.folderID = folderID
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.modelID = modelID
        self.systemPrompt = systemPrompt
        self.isPinned = isPinned
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, folderID, messages, createdAt, updatedAt, modelID, systemPrompt, isPinned
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.folderID = try c.decodeIfPresent(UUID.self, forKey: .folderID)
        self.messages = try c.decode([Message].self, forKey: .messages)
        self.createdAt = try c.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        self.modelID = try c.decodeIfPresent(String.self, forKey: .modelID)
        self.systemPrompt = try c.decodeIfPresent(String.self, forKey: .systemPrompt)
        self.isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(folderID, forKey: .folderID)
        try c.encode(messages, forKey: .messages)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encodeIfPresent(modelID, forKey: .modelID)
        try c.encodeIfPresent(systemPrompt, forKey: .systemPrompt)
        try c.encode(isPinned, forKey: .isPinned)
    }

    var approxTokenCount: Int {
        messages.reduce(0) { $0 + $1.content.approximateTokenCount }
    }

    var displayTokens: String {
        let count = approxTokenCount
        if count >= 1000 {
            return "\(count / 1000)K tokens"
        }
        return "\(count) tokens"
    }

    /// Sum of approximate prompt tokens (everything sent to the model on the next call).
    /// Same as `approxTokenCount` for now; named separately so cost-split helpers stay readable.
    var approxPromptTokens: Int { approxTokenCount }

    /// Approximate tokens for assistant messages only — used for cost estimation
    /// since OpenRouter charges different rates for prompt vs. completion.
    var approxCompletionTokens: Int {
        messages
            .filter { $0.role == .assistant }
            .reduce(0) { $0 + $1.content.approximateTokenCount }
    }

    /// Returns 0…1 if `contextLength` is known, else nil. Used for a warning when
    /// the conversation is approaching the model's window.
    func contextUsage(for model: OpenRouterModel?) -> Double? {
        guard let limit = model?.contextLength, limit > 0 else { return nil }
        return Double(approxTokenCount) / Double(limit)
    }

    /// USD cost estimate for the prompt+completions sent so far. Returns nil for free
    /// models (so the UI can hide the line) and 0.0 if pricing is unknown but provided.
    func estimatedCost(for model: OpenRouterModel?) -> Double? {
        guard let pricing = model?.pricing, !(model?.isFree ?? true) else { return nil }
        let promptCost = Double(approxPromptTokens) * pricing.prompt
        let completionCost = Double(approxCompletionTokens) * pricing.completion
        return promptCost + completionCost
    }

    /// Markdown rendering of the chat. Pure — no view-model state, so it's testable.
    var markdownExport: String {
        var lines: [String] = []
        lines.append("# \(name)")
        lines.append("")
        if let modelID {
            lines.append("_Model: \(modelID)_")
            lines.append("")
        }
        if let prompt = systemPrompt, !prompt.isEmpty {
            lines.append("## System")
            lines.append("")
            lines.append(prompt)
            lines.append("")
        }
        for message in messages {
            lines.append(message.role == .user ? "## User" : "## Assistant")
            lines.append("")
            lines.append(message.content)
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}
