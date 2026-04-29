import Foundation
import os

enum OpenRouterError: LocalizedError {
    case noAPIKey
    case invalidURL
    case noModelSelected
    case networkError(Error)
    case decodingError(Error, body: String?)
    case serverError(Int, String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Please add your API key in Settings."
        case .invalidURL:
            return "Invalid URL configuration."
        case .noModelSelected:
            return "Pick a model before sending a message."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error, _):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        }
    }
}

final class OpenRouterService {
    static let shared = OpenRouterService()

    private let session: URLSession
    private let logger = Logger(subsystem: "com.openrouter.desktop", category: "api")

    /// HTTP statuses we'll retry with exponential backoff. Everything else fails fast.
    private static let retryableStatuses: Set<Int> = [429, 500, 502, 503, 504]
    private static let maxAttempts = 3

    /// URLError codes worth retrying. Covers transient connectivity blips (DNS hiccup, dropped
    /// Wi-Fi, captive portal flap) — anything that's likely a different result a few seconds later.
    /// Auth-style failures (`userAuthenticationRequired`, `cancelled`) intentionally aren't here.
    private static let retryableURLErrorCodes: Set<URLError.Code> = [
        .timedOut,
        .networkConnectionLost,
        .notConnectedToInternet,
        .cannotFindHost,
        .cannotConnectToHost,
        .dnsLookupFailed,
        .resourceUnavailable,
        .internationalRoamingOff,
    ]

    private static func isTransient(_ error: URLError) -> Bool {
        retryableURLErrorCodes.contains(error.code)
    }

    /// Parsed result of a single SSE line. Pure — no I/O — so it's testable in isolation.
    enum SSELineResult: Equatable {
        case ignore             // non-data line (event:, comment, blank, role-only delta)
        case done               // OpenAI/OpenRouter "[DONE]" sentinel
        case delta(String)      // content fragment to yield
        case malformed(String)  // saw `data: ...` but couldn't decode — payload returned for logging
    }

    static func parseSSELine(_ line: String, decoder: JSONDecoder = JSONDecoder()) -> SSELineResult {
        guard line.hasPrefix("data: ") else { return .ignore }
        let payload = String(line.dropFirst(6))
        if payload == "[DONE]" { return .done }
        guard let data = payload.data(using: .utf8) else { return .malformed(payload) }
        do {
            let chunk = try decoder.decode(ChatCompletionStreamChunk.self, from: data)
            guard let delta = chunk.choices.first?.delta.content, !delta.isEmpty else { return .ignore }
            return .delta(delta)
        } catch {
            return .malformed(payload)
        }
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    private func authorizedRequest(path: String, method: String) throws -> URLRequest {
        guard let apiKey = KeychainService.shared.getAPIKey() else {
            throw OpenRouterError.noAPIKey
        }
        guard let url = URL(string: "\(AppConstants.openRouterBaseURL)\(path)") else {
            throw OpenRouterError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(AppConstants.appName, forHTTPHeaderField: "X-OpenRouter-Title")
        request.setValue(AppConstants.appReferer, forHTTPHeaderField: "HTTP-Referer")
        return request
    }

    private func backoffDelay(forAttempt attempt: Int) -> UInt64 {
        UInt64(pow(2.0, Double(attempt)) * 1_000_000_000)
    }

    func fetchModels() async throws -> [OpenRouterModel] {
        var lastError: Error = OpenRouterError.networkError(NSError(domain: "OpenRouter", code: -1))

        for attempt in 0..<Self.maxAttempts {
            do {
                let request = try authorizedRequest(path: "/models", method: "GET")
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw OpenRouterError.networkError(NSError(domain: "Invalid response", code: -1))
                }

                if Self.retryableStatuses.contains(httpResponse.statusCode) {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    logger.warning("retryable status \(httpResponse.statusCode) on /models: \(body, privacy: .private)")
                    lastError = OpenRouterError.serverError(httpResponse.statusCode, body)
                    try await Task.sleep(nanoseconds: backoffDelay(forAttempt: attempt))
                    continue
                }

                guard httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    logger.error("non-retryable status \(httpResponse.statusCode) on /models: \(errorMessage, privacy: .private)")
                    throw OpenRouterError.serverError(httpResponse.statusCode, errorMessage)
                }

                do {
                    let modelsResponse = try JSONDecoder().decode(ModelsResponse.self, from: data)
                    return modelsResponse.data.map { $0.toOpenRouterModel() }
                } catch {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    logger.error("decode failure on /models: \(error.localizedDescription, privacy: .public) body=\(body, privacy: .private)")
                    throw OpenRouterError.decodingError(error, body: body)
                }
            } catch let OpenRouterError.serverError(code, msg) where Self.retryableStatuses.contains(code) {
                lastError = OpenRouterError.serverError(code, msg)
                try? await Task.sleep(nanoseconds: backoffDelay(forAttempt: attempt))
                continue
            } catch let error as URLError where Self.isTransient(error) {
                lastError = OpenRouterError.networkError(error)
                logger.warning("transient network error on /models: \(error.localizedDescription, privacy: .public)")
                try? await Task.sleep(nanoseconds: backoffDelay(forAttempt: attempt))
                continue
            }
        }
        throw lastError
    }

    func streamChatCompletion(
        model: String,
        messages: [Message],
        systemPrompt: String? = nil,
        temperature: Double = DefaultParameters.temperature,
        maxTokens: Int = DefaultParameters.maxTokens
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { [weak self] in
                guard let self else { continuation.finish(); return }
                do {
                    guard !model.trimmingCharacters(in: .whitespaces).isEmpty else {
                        throw OpenRouterError.noModelSelected
                    }

                    let (bytes, _) = try await self.connectChatStream(
                        model: model,
                        messages: messages,
                        systemPrompt: systemPrompt,
                        temperature: temperature,
                        maxTokens: maxTokens
                    )

                    let decoder = JSONDecoder()
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        switch Self.parseSSELine(line, decoder: decoder) {
                        case .ignore:
                            continue
                        case .done:
                            continuation.finish()
                            return
                        case .delta(let chunk):
                            continuation.yield(chunk)
                        case .malformed(let payload):
                            self.logger.warning("malformed SSE chunk skipped: \(payload, privacy: .private)")
                        }
                    }
                    continuation.finish()
                } catch {
                    if Task.isCancelled {
                        continuation.finish()
                    } else {
                        continuation.finish(throwing: error)
                    }
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Establishes a streaming connection, retrying on transient errors. Returns once we have a 200
    /// and bytes are ready to be iterated.
    private func connectChatStream(
        model: String,
        messages: [Message],
        systemPrompt: String?,
        temperature: Double,
        maxTokens: Int
    ) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        var lastError: Error = OpenRouterError.networkError(NSError(domain: "OpenRouter", code: -1))

        var requestMessages: [ChatCompletionRequest.RequestMessage] = []
        if let systemPrompt, !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            requestMessages.append(.init(role: "system", content: systemPrompt))
        }
        requestMessages.append(contentsOf: messages.map {
            ChatCompletionRequest.RequestMessage(role: $0.role.rawValue, content: $0.content)
        })

        let body = ChatCompletionRequest(
            model: model,
            messages: requestMessages,
            temperature: temperature,
            maxTokens: maxTokens,
            stream: true
        )
        let bodyData = try JSONEncoder().encode(body)

        for attempt in 0..<Self.maxAttempts {
            do {
                var request = try authorizedRequest(path: "/chat/completions", method: "POST")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = bodyData

                let (bytes, response) = try await session.bytes(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw OpenRouterError.networkError(NSError(domain: "Invalid response", code: -1))
                }

                if Self.retryableStatuses.contains(httpResponse.statusCode) {
                    var errorBody = Data()
                    for try await byte in bytes { errorBody.append(byte) }
                    let bodyText = String(data: errorBody, encoding: .utf8) ?? ""
                    logger.warning("retryable status \(httpResponse.statusCode) on /chat/completions: \(bodyText, privacy: .private)")
                    lastError = OpenRouterError.serverError(httpResponse.statusCode, bodyText)
                    try await Task.sleep(nanoseconds: backoffDelay(forAttempt: attempt))
                    continue
                }

                guard httpResponse.statusCode == 200 else {
                    var errorBody = Data()
                    for try await byte in bytes { errorBody.append(byte) }
                    let bodyText = String(data: errorBody, encoding: .utf8) ?? "Unknown error"
                    logger.error("non-retryable status \(httpResponse.statusCode) on /chat/completions: \(bodyText, privacy: .private)")
                    throw OpenRouterError.serverError(httpResponse.statusCode, bodyText)
                }

                return (bytes, httpResponse)
            } catch let error as URLError where Self.isTransient(error) {
                lastError = OpenRouterError.networkError(error)
                logger.warning("transient network error on /chat/completions: \(error.localizedDescription, privacy: .public)")
                try? await Task.sleep(nanoseconds: backoffDelay(forAttempt: attempt))
                continue
            }
        }
        throw lastError
    }
}
