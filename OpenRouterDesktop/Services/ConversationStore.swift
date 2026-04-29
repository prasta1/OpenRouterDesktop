import Foundation
import os

final class ConversationStore {
    static let shared = ConversationStore()

    struct Index: Codable {
        var folders: [ChatFolder] = []
    }

    private let baseDir: URL
    private let conversationsDir: URL
    private let indexURL: URL
    private let legacyFileURL: URL

    private static let logger = Logger(subsystem: "com.openrouter.desktop", category: "store")

    private init() {
        self.baseDir = AppStorageDirectory.appSupport { Self.logger.error("\($0, privacy: .public)") }
        self.conversationsDir = baseDir.appendingPathComponent("conversations", isDirectory: true)
        self.indexURL = baseDir.appendingPathComponent("index.json")
        self.legacyFileURL = baseDir.appendingPathComponent("conversation.json")
        try? FileManager.default.createDirectory(at: conversationsDir, withIntermediateDirectories: true)
    }

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    func loadIndex() -> Index {
        guard let data = try? Data(contentsOf: indexURL) else { return Index() }
        return (try? decoder.decode(Index.self, from: data)) ?? Index()
    }

    func saveIndex(_ index: Index) {
        guard let data = try? encoder.encode(index) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    func loadAllConversations() -> [Conversation] {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: conversationsDir, includingPropertiesForKeys: nil) else {
            return []
        }
        return urls.compactMap { url -> Conversation? in
            guard url.pathExtension == "json" else { return nil }
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(Conversation.self, from: data)
        }
    }

    func save(_ conversation: Conversation) {
        let url = conversationsDir.appendingPathComponent("\(conversation.id.uuidString).json")
        guard let data = try? encoder.encode(conversation) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func delete(conversationID: UUID) {
        let url = conversationsDir.appendingPathComponent("\(conversationID.uuidString).json")
        try? FileManager.default.removeItem(at: url)
    }

    /// One-shot migration from the v1 single-file `conversation.json` layout.
    /// Returns a `Conversation` if legacy data was found; otherwise nil. Removes the legacy file on success.
    func migrateLegacyConversation() -> Conversation? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: legacyFileURL.path),
              let data = try? Data(contentsOf: legacyFileURL) else { return nil }
        guard let convo = Self.makeMigratedConversation(from: data, decoder: decoder) else { return nil }
        save(convo)
        try? fm.removeItem(at: legacyFileURL)
        return convo
    }

    /// Pure rendering of the migration logic — no IO, so it's unit-testable.
    /// Returns nil if `data` doesn't decode as `[Message]` or contains no messages.
    static func makeMigratedConversation(from data: Data, decoder: JSONDecoder) -> Conversation? {
        guard let messages = try? decoder.decode([Message].self, from: data),
              !messages.isEmpty else { return nil }
        let firstUserContent = messages.first(where: { $0.role == .user })?.content ?? "Imported chat"
        let name = String(firstUserContent.prefix(40)).trimmingCharacters(in: .whitespacesAndNewlines)
        return Conversation(
            id: UUID(),
            name: name.isEmpty ? "Imported chat" : name,
            folderID: nil,
            messages: messages,
            createdAt: messages.first?.timestamp ?? Date(),
            updatedAt: messages.last?.timestamp ?? Date(),
            modelID: nil
        )
    }
}
