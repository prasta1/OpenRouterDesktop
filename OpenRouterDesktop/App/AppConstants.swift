import Foundation

enum AppConstants {
    static let appName = "OpenRouterDesktop"
    static let appReferer = "https://openrouter.ai"
    static let openRouterBaseURL = "https://openrouter.ai/api/v1"
    static let keychainService = "com.openrouter.desktop"
    static let conversationDirectory = "OpenRouterDesktop"
}

enum PreferenceKeys {
    static let selectedModelId = "selectedModelId"
    static let temperature = "temperature"
    static let maxTokens = "maxTokens"
    static let freeModelsOnly = "freeModelsOnly"
}

enum DefaultParameters {
    static let temperature: Double = 0.7
    static let maxTokens: Int = 4096
}

extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}

extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}

extension String {
    /// Approximate BPE token count tuned for GPT/Claude/Llama-family tokenizers.
    /// Takes the larger of two heuristics — chars/4 (good for code, dense text) and
    /// words*4/3 (good for prose, accounts for word-piece splitting). Better than chars/4
    /// alone for English text where words average ~5 chars + a space.
    var approximateTokenCount: Int {
        let chars = self.count
        let words = self.split(whereSeparator: { $0.isWhitespace }).count
        return max(chars / 4, (words * 4) / 3)
    }
}

/// Returns the app's persistent storage root, creating it if needed. Falls back to the temporary
/// directory if Application Support is unreachable so app init never traps. The fallback path is
/// session-only — chats won't survive a restart, but the app stays usable.
/// Named `AppStorageDirectory` to avoid colliding with SwiftUI's `AppStorage` property wrapper.
enum AppStorageDirectory {
    static func appSupport(logger: ((String) -> Void)? = nil) -> URL {
        let fm = FileManager.default
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let dir = appSupport.appendingPathComponent(AppConstants.conversationDirectory, isDirectory: true)
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                return dir
            } catch {
                logger?("Could not create Application Support dir, falling back to temp: \(error.localizedDescription)")
            }
        } else {
            logger?("Application Support unavailable; falling back to temp directory.")
        }
        let tmp = fm.temporaryDirectory.appendingPathComponent(AppConstants.conversationDirectory, isDirectory: true)
        try? fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        return tmp
    }
}
