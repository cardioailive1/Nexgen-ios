import SwiftUI
import PDFKit
import UniformTypeIdentifiers

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var input = ""
    @Published var isStreaming = false
    @Published var mode: ChatMode = .chat
    /// "Explainable AI" — appends the reasoning/confidence block to answers.
    @Published var xaiEnabled = false
    /// Stream tokens as they arrive vs. wait for the full reply.
    @Published var streamEnabled = true
    /// Pending image attachment (JPEG data) awaiting send.
    @Published var pendingImageData: Data?
    /// Pending document attachment (name + extracted text) awaiting send.
    @Published var pendingDoc: (name: String, text: String)?
    /// Drives the one-time third-party AI data consent sheet. Set when a send is
    /// attempted before consent has been granted.
    @Published var showConsent = false

    let store: ConversationStore
    private let service: ChatServicing
    private let subscriptions: SubscriptionManager
    private let upgrade: UpgradeViewModel
    let consent: AIConsentManager
    private var streamTask: Task<Void, Never>?

    init(store: ConversationStore,
         service: ChatServicing,
         subscriptions: SubscriptionManager,
         upgrade: UpgradeViewModel,
         consent: AIConsentManager) {
        self.store = store
        self.service = service
        self.subscriptions = subscriptions
        self.upgrade = upgrade
        self.consent = consent
    }

    /// Models the current plan is allowed to use.
    var lockedModels: Set<AIModel> {
        let plan = subscriptions.currentPlan
        return Set(AIModel.allCases.filter { model in
            guard let plan else { return true }
            return !plan.canUse(model)
        })
    }

    var messages: [ChatMessage] { store.selected?.messages ?? [] }

    var selectedModel: AIModel { store.selected?.model ?? .pro }

    var canSend: Bool {
        guard !isStreaming else { return false }
        let hasText = !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasText || pendingImageData != nil || pendingDoc != nil
    }

    var pendingImage: UIImage? {
        pendingImageData.flatMap(UIImage.init(data:))
    }

    func attachImage(_ data: Data) {
        // Re-encode to JPEG to normalize the media type and shrink payloads.
        if let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.7) {
            pendingImageData = jpeg
        } else {
            pendingImageData = data
        }
    }

    func removeImage() { pendingImageData = nil }

    func removeDoc() { pendingDoc = nil }

    /// Extract text from a picked document (PDF or plain text) and stage it.
    func attachDocument(_ url: URL) {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
        let name = url.lastPathComponent
        guard let text = Self.extractText(from: url), !text.isEmpty else {
            pendingDoc = (name, "[Could not read file contents]")
            return
        }
        pendingDoc = (name, text)
    }

    private static func extractText(from url: URL) -> String? {
        if url.pathExtension.lowercased() == "pdf", let pdf = PDFDocument(url: url) {
            return pdf.string
        }
        // Plain text and anything decodable as UTF-8/ASCII.
        if let data = try? Data(contentsOf: url) {
            return String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
        }
        return nil
    }

    /// Build the user message text with any attached document appended, mirroring
    /// the web app's `buildMsgContent`.
    private func composeText(_ base: String) -> String {
        guard let doc = pendingDoc else { return base }
        let limit = 12000
        let preview = String(doc.text.prefix(limit))
        let trunc = doc.text.count > limit
            ? "\n...[truncated, total \(doc.text.count / 1024)KB]" : ""
        var txt = base
        txt += "\n\n---\nAttached file: \(doc.name)\n```\n\(preview)\(trunc)\n```"
        return txt
    }

    // MARK: - Actions

    func selectModel(_ model: AIModel) {
        // Gate model access by plan, mirroring the web app's switchModel(): a
        // model the current plan can't use opens the "change plan" wall instead.
        if let plan = subscriptions.currentPlan, !plan.canUse(model) {
            upgrade.present()
            return
        }
        if store.selected == nil { store.newConversation(model: model) }
        store.setModel(model)
    }

    func send() {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageData = pendingImageData
        let hasDoc = pendingDoc != nil
        guard !text.isEmpty || imageData != nil || hasDoc, !isStreaming else { return }

        // Block sending to the third-party AI service until the user has granted
        // permission (guidelines 5.1.1(i) / 5.1.2(i)). Input is preserved so the
        // send resumes after consent. `grantConsentAndSend()` re-enters here.
        guard consent.hasConsented else {
            showConsent = true
            return
        }

        // No caption but an attachment present → default prompt (mirrors web).
        if text.isEmpty, imageData != nil {
            text = "Describe this image in detail."
        } else if text.isEmpty, hasDoc {
            text = "Analyse the attached file(s) and provide detailed insights."
        }

        // Append document contents to the message text.
        let bodyText = composeText(text)

        let model = selectedModel
        let userMessage = ChatMessage(
            role: .user,
            text: bodyText,
            imageBase64: imageData?.base64EncodedString(),
            imageMediaType: imageData != nil ? "image/jpeg" : nil
        )
        store.append(userMessage, model: model)
        input = ""
        pendingImageData = nil
        pendingDoc = nil

        let assistant = ChatMessage(role: .assistant, text: "", isStreaming: true)
        store.append(assistant, model: model)

        isStreaming = true
        streamTask = Task { [weak self] in
            guard let self else { return }
            let history = self.store.selected?.messages ?? []
            do {
                var systemExtra = self.mode.systemPrompt
                if self.xaiEnabled {
                    systemExtra += (systemExtra.isEmpty ? "" : "\n\n") + AppConfig.xaiSuffix
                }
                for try await chunk in self.service.streamCompletion(
                    model: model,
                    history: history,
                    systemExtra: systemExtra,
                    stream: self.streamEnabled
                ) {
                    if Task.isCancelled { break }
                    self.store.appendChunk(chunk, to: assistant.id)
                }
            } catch {
                let message = (error as? NetworkError)?.errorDescription
                    ?? "The assistant couldn't respond. Please try again."
                self.store.appendChunk("", to: assistant.id)
                self.store.append(ChatMessage(role: .error, text: message), model: model)
            }
            self.store.finishStreaming(assistant.id)
            self.isStreaming = false
        }
    }

    /// Grant AI data consent and resume the pending send.
    func grantConsentAndSend() {
        consent.grant()
        showConsent = false
        send()
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        if let last = store.selected?.messages.last, last.isStreaming {
            store.finishStreaming(last.id)
        }
    }

    func clear() {
        stop()
        store.clearSelectedMessages()
    }
}
