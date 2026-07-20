import SwiftUI

// MARK: - AI model tier

/// The three selectable model tiers, mirroring the web app's Flash/Pro/Ultra tabs.
enum AIModel: String, CaseIterable, Identifiable, Codable {
    case flash, pro, ultra

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flash: return "Flash"
        case .pro:   return "Pro"
        case .ultra: return "Ultra"
        }
    }

    var subtitle: String {
        switch self {
        case .flash: return "Fast & efficient"
        case .pro:   return "Balanced & capable"
        case .ultra: return "Deep reasoning"
        }
    }

    var icon: String {
        switch self {
        case .flash: return "bolt.fill"
        case .pro:   return "sparkles"
        case .ultra: return "brain.head.profile"
        }
    }

    var tint: Color {
        switch self {
        case .flash: return AppColor.flash
        case .pro:   return AppColor.pro
        case .ultra: return AppColor.ultra
        }
    }

    /// Anthropic model identifier sent to the Messages API, mirroring the web
    /// app's `MODELS[m].id`.
    var apiModelID: String {
        switch self {
        case .flash: return "claude-haiku-4-5-20251001"
        case .pro:   return "claude-sonnet-4-6"
        case .ultra: return "claude-opus-4-6"
        }
    }
}

// MARK: - Message

struct ChatMessage: Identifiable, Equatable, Codable {
    enum Role: String, Codable {
        case user, assistant, system, error
    }

    let id: UUID
    let role: Role
    var text: String
    var timestamp: Date
    var isStreaming: Bool
    /// Base64-encoded image attachment (user messages, vision), if any.
    var imageBase64: String?
    /// MIME type for `imageBase64` (e.g. "image/jpeg", "image/png").
    var imageMediaType: String?

    init(id: UUID = UUID(),
         role: Role,
         text: String,
         timestamp: Date = Date(),
         isStreaming: Bool = false,
         imageBase64: String? = nil,
         imageMediaType: String? = nil) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.imageBase64 = imageBase64
        self.imageMediaType = imageMediaType
    }
}

// MARK: - Conversation

struct Conversation: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    var model: AIModel
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         title: String = "New chat",
         messages: [ChatMessage] = [],
         model: AIModel = .pro,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.model = model
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Last assistant/user line, used as a preview in the sidebar.
    var preview: String {
        messages.last(where: { $0.role == .user || $0.role == .assistant })?.text ?? "No messages yet"
    }
}

// MARK: - API payloads

struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [Payload]
    let stream: Bool

    struct Payload: Encodable {
        let role: String
        let content: String
    }
}
