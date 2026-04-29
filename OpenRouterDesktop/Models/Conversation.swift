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
}
