import Foundation

/// Streams assistant tokens for a chat completion.
protocol ChatServicing {
    /// Returns an async stream of incremental text chunks. `systemExtra` is the
    /// active chat mode's system prompt (+ optional XAI), appended after the base
    /// prompt. When `stream` is false the full reply is yielded in one chunk.
    func streamCompletion(model: AIModel,
                          history: [ChatMessage],
                          systemExtra: String,
                          stream: Bool) -> AsyncThrowingStream<String, Error>
}

extension ChatServicing {
    func streamCompletion(model: AIModel,
                          history: [ChatMessage],
                          systemExtra: String = "",
                          stream: Bool = true) -> AsyncThrowingStream<String, Error> {
        streamCompletion(model: model, history: history, systemExtra: systemExtra, stream: stream)
    }
}

// MARK: - Live (Anthropic SSE) implementation

/// Streams assistant tokens directly from the Anthropic Messages API
/// (`https://api.anthropic.com/v1/messages`), mirroring the web app's
/// `callNexGen`. Parses SSE `content_block_delta` / `text_delta` events.
final class ChatAPIService: ChatServicing {
    private let session: URLSession
    /// Returns the live geo/weather context appended to the system prompt.
    private let geoContext: () -> String

    init(session: URLSession = .shared,
         geoContext: @escaping () -> String = { "" }) {
        self.session = session
        self.geoContext = geoContext
    }

    func streamCompletion(model: AIModel,
                          history: [ChatMessage],
                          systemExtra: String,
                          stream: Bool) -> AsyncThrowingStream<String, Error> {
        var systemPrompt = AppConfig.chatSystemPrompt + geoContext()
        if !systemExtra.isEmpty { systemPrompt += "\n\n" + systemExtra }
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try Self.makeRequest(model: model,
                                                       history: history,
                                                       system: systemPrompt,
                                                       stream: stream)
                    if stream {
                        try await self.consumeStream(request, into: continuation)
                    } else {
                        try await self.consumeFull(request, into: continuation)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// SSE path — yields `text_delta` chunks as they arrive.
    private func consumeStream(_ request: URLRequest,
                               into continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            var raw = ""
            for try await line in bytes.lines { raw += line }
            throw NetworkError.server(status: http.statusCode, message: Self.parseError(raw))
        }
        for try await line in bytes.lines {
            if Task.isCancelled { break }
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if let chunk = Self.parseDelta(payload) { continuation.yield(chunk) }
        }
    }

    /// Non-streaming path — one request, yields the full reply in one chunk.
    private func consumeFull(_ request: URLRequest,
                             into continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw NetworkError.server(status: http.statusCode,
                                      message: Self.parseError(String(data: data, encoding: .utf8) ?? ""))
        }
        if let text = Self.parseFullText(data) { continuation.yield(text) }
    }

    // MARK: - Request

    private static func makeRequest(model: AIModel,
                                    history: [ChatMessage],
                                    system: String,
                                    stream: Bool) throws -> URLRequest {
        let messages = history
            .filter { $0.role == .user || $0.role == .assistant }
            .map {
                AnthropicRequest.Message(
                    role: $0.role.rawValue,
                    text: $0.text,
                    imageBase64: $0.imageBase64,
                    imageMediaType: $0.imageMediaType
                )
            }

        let body = AnthropicRequest(
            model: model.apiModelID,
            maxTokens: AppConfig.chatMaxTokens,
            system: system,
            stream: stream,
            messages: messages
        )
        let payload = try JSONEncoder().encode(body)

        return AppConfig.useDirectAnthropicKey
            ? directRequest(payload)
            : proxyRequest(payload)
    }

    /// Direct-to-Anthropic request using the key in `Secrets.plist`.
    private static func directRequest(_ payload: Data) -> URLRequest {
        var request = URLRequest(url: AppConfig.anthropicURL,
                                 timeoutInterval: AppConfig.requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(AppConfig.anthropicAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue(AppConfig.anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = payload
        return request
    }

    /// Request routed through the Supabase Edge Function proxy. No Anthropic key
    /// is sent — the function holds it server-side and authorizes the call by the
    /// signed-in user's Supabase JWT (falling back to the anon key).
    private static func proxyRequest(_ payload: Data) -> URLRequest {
        var request = URLRequest(url: AppConfig.chatProxyURL,
                                 timeoutInterval: AppConfig.requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        let jwt = APIClient.shared.authTokenProvider?() ?? AppConfig.supabaseAnonKey
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.httpBody = payload
        return request
    }

    /// Joins the text blocks of a non-streaming Anthropic response
    /// (`{content:[{type:"text", text:"..."}]}`).
    private static func parseFullText(_ data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = obj["content"] as? [[String: Any]] else {
            return nil
        }
        let text = content.compactMap { block -> String? in
            block["type"] as? String == "text" ? block["text"] as? String : nil
        }.joined()
        return text.isEmpty ? nil : text
    }

    /// Extracts the human-readable message from an Anthropic error body:
    /// `{"type":"error","error":{"type":"...","message":"..."}}`.
    private static func parseError(_ raw: String) -> String? {
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = obj["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return raw.isEmpty ? nil : raw
        }
        // Provider-side account/billing problems (e.g. "credit balance is too
        // low") are not the user's subscription and must never surface as a
        // "low balance" message — that reads as a fault with the user's plan
        // (Apple guideline 2.1(a)). Map to a neutral, actionable message.
        let lowered = message.lowercased()
        if lowered.contains("credit balance") || lowered.contains("billing")
            || lowered.contains("quota") || lowered.contains("insufficient") {
            return "The assistant is temporarily unavailable. Please try again later, or contact support@corverxis.com if this continues."
        }
        return message
    }

    /// Extracts `delta.text` from an Anthropic streaming event.
    private static func parseDelta(_ json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              obj["type"] as? String == "content_block_delta",
              let delta = obj["delta"] as? [String: Any],
              delta["type"] as? String == "text_delta",
              let text = delta["text"] as? String else {
            return nil
        }
        return text
    }
}

/// Anthropic Messages API request body.
private struct AnthropicRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let stream: Bool
    let messages: [Message]

    /// A message whose `content` encodes as a plain string, or — when an image is
    /// attached — as an Anthropic multimodal content block array
    /// (`[{type:image, source:{type:base64,...}}, {type:text, text}]`).
    struct Message: Encodable {
        let role: String
        let text: String
        var imageBase64: String?
        var imageMediaType: String?

        enum Keys: String, CodingKey { case role, content }
        enum BlockKeys: String, CodingKey { case type, text, source }
        enum SourceKeys: String, CodingKey {
            case type, data
            case mediaType = "media_type"
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: Keys.self)
            try c.encode(role, forKey: .role)

            guard let img = imageBase64, let mime = imageMediaType else {
                try c.encode(text, forKey: .content)
                return
            }

            var blocks = c.nestedUnkeyedContainer(forKey: .content)
            var imageBlock = blocks.nestedContainer(keyedBy: BlockKeys.self)
            try imageBlock.encode("image", forKey: .type)
            var source = imageBlock.nestedContainer(keyedBy: SourceKeys.self, forKey: .source)
            try source.encode("base64", forKey: .type)
            try source.encode(mime, forKey: .mediaType)
            try source.encode(img, forKey: .data)

            var textBlock = blocks.nestedContainer(keyedBy: BlockKeys.self)
            try textBlock.encode("text", forKey: .type)
            try textBlock.encode(text, forKey: .text)
        }
    }

    enum CodingKeys: String, CodingKey {
        case model, system, stream, messages
        case maxTokens = "max_tokens"
    }
}

// MARK: - Mock implementation

/// Simulated streaming used when no real backend is configured, so the UI is
/// fully runnable in the simulator and previews.
final class MockChatService: ChatServicing {
    func streamCompletion(model: AIModel,
                          history: [ChatMessage],
                          systemExtra: String = "",
                          stream: Bool = true) -> AsyncThrowingStream<String, Error> {
        let reply = Self.sampleReply(for: model)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for word in reply.split(separator: " ", omittingEmptySubsequences: false) {
                        try await Task.sleep(nanoseconds: 45_000_000)
                        continuation.yield(String(word) + " ")
                    }
                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func sampleReply(for model: AIModel) -> String {
        switch model {
        case .flash:
            return "Here's a quick take. Flash is tuned for speed, so I keep answers tight and practical. Ask me anything and I'll respond in a flash."
        case .pro:
            return "Happy to help. Pro balances depth and speed, so I can reason through most problems while staying responsive. What would you like to explore?"
        case .ultra:
            return "Let me think this through carefully. Ultra is built for deep reasoning and long-form work, so I can break complex problems into clear steps and weigh trade-offs before answering."
        }
    }
}
