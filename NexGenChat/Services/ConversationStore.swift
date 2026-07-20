import SwiftUI
import Combine

/// Single source of truth for all conversations, shared by the Chat screen and
/// the Conversations sidebar. Persisted to JSON on disk (mirrors the web app's
/// `saveConvs`/`loadConvs` localStorage), so chats survive relaunch.
@MainActor
final class ConversationStore: ObservableObject {
    @Published private(set) var conversations: [Conversation]
    @Published var selectedID: UUID?

    private let persistenceURL: URL?

    init(conversations: [Conversation]? = nil) {
        let url = Self.defaultURL()
        self.persistenceURL = url
        let loaded = conversations ?? Self.load(from: url)
        self.conversations = loaded
        self.selectedID = loaded.first?.id
    }

    var selected: Conversation? {
        guard let selectedID else { return nil }
        return conversations.first { $0.id == selectedID }
    }

    // MARK: - Lifecycle

    @discardableResult
    func newConversation(model: AIModel = .pro) -> Conversation {
        let convo = Conversation(model: model)
        conversations.insert(convo, at: 0)
        selectedID = convo.id
        save()
        return convo
    }

    func select(_ id: UUID) {
        selectedID = id
    }

    func delete(_ id: UUID) {
        conversations.removeAll { $0.id == id }
        if selectedID == id { selectedID = conversations.first?.id }
        save()
    }

    func deleteAll() {
        conversations.removeAll()
        selectedID = nil
        save()
    }

    // MARK: - Message mutations (operate on the selected conversation)

    /// Ensures a conversation exists to write into, creating one on demand.
    @discardableResult
    private func ensureSelected(model: AIModel) -> UUID {
        if let id = selectedID { return id }
        return newConversation(model: model).id
    }

    func append(_ message: ChatMessage, model: AIModel) {
        let id = ensureSelected(model: model)
        mutate(id) { convo in
            convo.messages.append(message)
            convo.updatedAt = Date()
            if convo.title == "New chat", message.role == .user {
                convo.title = Self.makeTitle(from: message.text)
            }
        }
        save()
    }

    /// Appends streamed text to an existing message (by id) in the selected chat.
    func appendChunk(_ chunk: String, to messageID: UUID) {
        guard let id = selectedID else { return }
        mutate(id) { convo in
            if let idx = convo.messages.firstIndex(where: { $0.id == messageID }) {
                convo.messages[idx].text += chunk
                convo.updatedAt = Date()
            }
        }
    }

    func finishStreaming(_ messageID: UUID) {
        guard let id = selectedID else { return }
        mutate(id) { convo in
            if let idx = convo.messages.firstIndex(where: { $0.id == messageID }) {
                convo.messages[idx].isStreaming = false
            }
        }
        save() // response complete — persist the full assistant message
    }

    func clearSelectedMessages() {
        guard let id = selectedID else { return }
        mutate(id) { convo in
            convo.messages.removeAll()
            convo.title = "New chat"
        }
        save()
    }

    func setModel(_ model: AIModel) {
        guard let id = selectedID else { return }
        mutate(id) { $0.model = model }
        save()
    }

    // MARK: - Helpers

    private func mutate(_ id: UUID, _ transform: (inout Conversation) -> Void) {
        guard let idx = conversations.firstIndex(where: { $0.id == id }) else { return }
        transform(&conversations[idx])
        // Keep most-recently-updated conversation at the top.
        conversations.sort { $0.updatedAt > $1.updatedAt }
    }

    private static func makeTitle(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(40))
    }

    // MARK: - Persistence

    /// Write the current conversations to disk. Called after structural changes
    /// and when a response finishes (not on every streamed token).
    func save() {
        guard let url = persistenceURL else { return }
        do {
            let data = try JSONEncoder().encode(conversations)
            try data.write(to: url, options: .atomic)
        } catch {
            // Non-fatal: persistence is best-effort.
        }
    }

    private static func load(from url: URL?) -> [Conversation] {
        guard let url, let data = try? Data(contentsOf: url),
              let convos = try? JSONDecoder().decode([Conversation].self, from: data) else {
            return []
        }
        return convos
    }

    private static func defaultURL() -> URL? {
        let fm = FileManager.default
        guard let dir = try? fm.url(for: .applicationSupportDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: true) else { return nil }
        return dir.appendingPathComponent("conversations.json")
    }
}
