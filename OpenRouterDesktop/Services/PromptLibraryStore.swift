import Foundation
import os

final class PromptLibraryStore {
    static let shared = PromptLibraryStore()

    private let fileURL: URL

    private static let logger = Logger(subsystem: "com.openrouter.desktop", category: "store")

    private init() {
        let dir = AppStorageDirectory.appSupport { Self.logger.error("\($0, privacy: .public)") }
        self.fileURL = dir.appendingPathComponent("prompts.json")
    }

    /// Returns nil if the file doesn't exist (first launch). Returns [] if the user has explicitly
    /// emptied the library. The distinction matters for seeding.
    func load() -> [PromptTemplate]? {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([PromptTemplate].self, from: data)
    }

    func save(_ prompts: [PromptTemplate]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(prompts) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
