import SwiftUI

/// The main chat screen: header, model selector, scrolling transcript, and the
/// input composer. Hosts one conversation from the shared store.
struct ChatView: View {
    @StateObject var viewModel: ChatViewModel
    @ObservedObject var store: ConversationStore
    let onOpenMenu: () -> Void

    @State private var shareItem: ShareItem?
    @State private var showPrivacy = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ModelSelectorView(selected: viewModel.selectedModel,
                              lockedModels: viewModel.lockedModels) { model in
                viewModel.selectModel(model)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.sm)

            modeBar

            Divider().overlay(AppColor.lift)

            transcript

            ChatInputBar(
                text: $viewModel.input,
                isStreaming: viewModel.isStreaming,
                canSend: viewModel.canSend,
                onSend: viewModel.send,
                onStop: viewModel.stop,
                placeholder: viewModel.mode.placeholder,
                pendingImage: viewModel.pendingImage,
                onImagePicked: viewModel.attachImage,
                onRemoveImage: viewModel.removeImage,
                pendingDocName: viewModel.pendingDoc?.name,
                onDocPicked: viewModel.attachDocument,
                onRemoveDoc: viewModel.removeDoc
            )
        }
        .background(AppColor.backgroundGradient.ignoresSafeArea())
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .sheet(isPresented: $viewModel.showConsent) {
            AIConsentView(
                onAccept: { viewModel.grantConsentAndSend() },
                onDecline: { viewModel.showConsent = false },
                onShowPrivacy: { showPrivacy = true }
            )
        }
        .sheet(isPresented: $showPrivacy) { PrivacyPolicyView() }
    }

    private func exportPDF() {
        guard let conversation = store.selected,
              let url = ChatPDFExporter.export(conversation) else { return }
        shareItem = ShareItem(url: url)
    }

    private func exportWord() {
        guard let conversation = store.selected,
              let url = ChatDocExporter.export(conversation) else { return }
        shareItem = ShareItem(url: url)
    }

    private func exportPowerPoint() {
        guard let conversation = store.selected,
              let url = ChatPptxExporter.export(conversation) else { return }
        shareItem = ShareItem(url: url)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Spacing.md) {
            Button(action: onOpenMenu) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppColor.text)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(store.selected?.title ?? AppConstants.appName)
                    .font(AppFont.headline())
                    .foregroundStyle(AppColor.text)
                    .lineLimit(1)
                Text(viewModel.selectedModel.subtitle)
                    .font(AppFont.caption())
                    .foregroundStyle(viewModel.selectedModel.tint)
            }

            Spacer()

            Menu {
                Toggle(isOn: $viewModel.xaiEnabled) {
                    Label("Explainable AI", systemImage: "brain.head.profile")
                }
                Toggle(isOn: $viewModel.streamEnabled) {
                    Label("Stream responses", systemImage: "dot.radiowaves.left.and.right")
                }
                Divider()
                Button { exportPDF() } label: {
                    Label("Export as PDF", systemImage: "square.and.arrow.up")
                }
                Button { exportWord() } label: {
                    Label("Export as Word", systemImage: "doc.richtext")
                }
                Button { exportPowerPoint() } label: {
                    Label("Export as PowerPoint", systemImage: "rectangle.on.rectangle")
                }
                Button(role: .destructive) { viewModel.clear() } label: {
                    Label("Clear conversation", systemImage: "trash")
                }
                Button { store.newConversation(model: viewModel.selectedModel) } label: {
                    Label("New chat", systemImage: "square.and.pencil")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColor.text)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Mode bar

    private var modeBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(ChatMode.available) { mode in
                    let selected = viewModel.mode == mode
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { viewModel.mode = mode }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(mode.displayName)
                                .font(AppFont.caption())
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(selected ? .white : AppColor.muted)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 6)
                        .background(selected ? AnyShapeStyle(AppColor.accent)
                                             : AnyShapeStyle(AppColor.panel))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Transcript

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if viewModel.messages.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: Spacing.lg) {
                        ForEach(viewModel.messages) { message in
                            ChatBubbleView(message: message, modelTint: viewModel.selectedModel.tint)
                                .id(message.id)
                        }
                        Color.clear.frame(height: 1).id(bottomAnchor)
                    }
                    .padding(Spacing.lg)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.last?.text) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(bottomAnchor, anchor: .bottom)
                }
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation { proxy.scrollTo(bottomAnchor, anchor: .bottom) }
            }
        }
    }

    private var bottomAnchor: String { "chat-bottom" }

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            NexGenLogoMark(size: 64)
            Text("How can I help today?")
                .font(AppFont.title())
                .foregroundStyle(AppColor.text)
            Text("Pick a model above and start the conversation.")
                .font(AppFont.callout())
                .foregroundStyle(AppColor.dim)
                .multilineTextAlignment(.center)

            VStack(spacing: Spacing.sm) {
                ForEach(Self.suggestions, id: \.self) { suggestion in
                    Button {
                        viewModel.input = suggestion
                        viewModel.send()
                    } label: {
                        Text(suggestion)
                            .font(AppFont.callout())
                            .foregroundStyle(AppColor.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Spacing.md)
                            .background(AppColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, Spacing.md)
        }
        .padding(Spacing.xl)
        .padding(.top, Spacing.xxxl)
    }

    private static let suggestions = [
        "Summarize a long document for me",
        "Draft a professional email",
        "Explain a complex topic simply"
    ]
}

#Preview {
    let store = ConversationStore(conversations: [Conversation()])
    let subs = SubscriptionManager()
    let upgrade = UpgradeViewModel(subscriptions: subs)
    return ChatView(
        viewModel: ChatViewModel(store: store,
                                 service: MockChatService(),
                                 subscriptions: subs,
                                 upgrade: upgrade,
                                 consent: AIConsentManager()),
        store: store,
        onOpenMenu: {}
    )
    .preferredColorScheme(.dark)
}
