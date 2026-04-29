import Foundation

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [RequestMessage]
    let temperature: Double?
    let maxTokens: Int?
    let stream: Bool?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
        case stream
    }

    struct RequestMessage: Codable {
        let role: String
        let content: String
    }
}

struct ChatCompletionStreamChunk: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let delta: Delta
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case delta
            case finishReason = "finish_reason"
        }
    }

    struct Delta: Codable {
        let role: String?
        let content: String?
    }
}
