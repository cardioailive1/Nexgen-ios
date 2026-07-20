import SwiftUI

@MainActor
final class ConversationsViewModel: ObservableObject {
    @Published var search = ""

    let store: ConversationStore

    init(store: ConversationStore) {
        self.store = store
    }

    var filtered: [Conversation] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return store.conversations }
        return store.conversations.filter {
            $0.title.lowercased().contains(query)
                || $0.preview.lowercased().contains(query)
        }
    }

    var selectedID: UUID? { store.selectedID }

    func newChat() { store.newConversation() }
    func select(_ id: UUID) { store.select(id) }
    func delete(_ id: UUID) { store.delete(id) }
    func clearAll() { store.deleteAll() }
}
