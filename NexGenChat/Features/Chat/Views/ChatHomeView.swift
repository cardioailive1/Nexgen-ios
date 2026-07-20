import SwiftUI

/// Authenticated home: the Chat screen with a slide-in Conversations sidebar
/// drawer, mirroring the web app's left menu.
struct ChatHomeView: View {
    @StateObject private var store: ConversationStore
    @StateObject private var chatViewModel: ChatViewModel
    @StateObject private var conversationsViewModel: ConversationsViewModel
    @StateObject private var upgradeViewModel: UpgradeViewModel
    @ObservedObject private var subscriptions: SubscriptionManager
    private let consent: AIConsentManager

    @State private var isMenuOpen = false
    @State private var showSettings = false

    private let drawerWidth: CGFloat = min(320, UIScreen.main.bounds.width * 0.84)

    init(container: DIContainer = .shared) {
        let store = container.conversationStore
        let upgrade = container.makeUpgradeViewModel()
        _store = StateObject(wrappedValue: store)
        _upgradeViewModel = StateObject(wrappedValue: upgrade)
        _chatViewModel = StateObject(wrappedValue: container.makeChatViewModel(upgradeViewModel: upgrade))
        _conversationsViewModel = StateObject(wrappedValue: container.makeConversationsViewModel())
        subscriptions = container.subscriptionManager
        consent = container.aiConsentManager
    }

    var body: some View {
        drawerStack
            .overlay {
                if upgradeViewModel.isPresented {
                    UpgradeWallView(viewModel: upgradeViewModel)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: upgradeViewModel.isPresented)
            .sheet(isPresented: $showSettings) {
                SettingsView(
                    authManager: DIContainer.shared.authManager,
                    subscriptions: subscriptions,
                    consent: consent,
                    onChangePlan: { upgradeViewModel.present() }
                )
                .environmentObject(DIContainer.shared.authManager)
            }
            .onAppear { gateOnSubscription() }
            .onChange(of: subscriptions.currentPlan) { _ in gateOnSubscription() }
            .onChange(of: subscriptions.hasResolvedEntitlements) { _ in gateOnSubscription() }
    }

    private var drawerStack: some View {
        ZStack(alignment: .leading) {
            // Main chat, pushed right when the drawer opens.
            ChatView(viewModel: chatViewModel, store: store) {
                openMenu()
            }
            .disabled(isMenuOpen)
            .offset(x: isMenuOpen ? drawerWidth * 0.9 : 0)
            .scaleEffect(isMenuOpen ? 0.94 : 1, anchor: .trailing)

            // Dimming scrim.
            if isMenuOpen {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture { closeMenu() }
                    .transition(.opacity)
            }

            // The drawer itself.
            ConversationsSidebarView(
                viewModel: conversationsViewModel,
                onSelectConversation: { closeMenu() },
                onOpenSettings: {
                    closeMenu()
                    showSettings = true
                }
            )
            .frame(width: drawerWidth)
            .offset(x: isMenuOpen ? 0 : -drawerWidth - 8)
            .shadow(color: .black.opacity(isMenuOpen ? 0.4 : 0), radius: 16, x: 6)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isMenuOpen)
        .gesture(edgeDragGesture)
        .onAppear {
            if store.conversations.isEmpty { store.newConversation() }
        }
    }

    // MARK: - Menu control

    /// After login/signup, block the app behind the upgrade wall until a
    /// subscription is active. Waits for the first entitlement check so an
    /// already-subscribed user never sees the wall flash.
    private func gateOnSubscription() {
        guard subscriptions.hasResolvedEntitlements else { return }
        if subscriptions.hasActiveSubscription {
            if upgradeViewModel.isBlocking { upgradeViewModel.forceDismiss() }
        } else {
            upgradeViewModel.presentBlocking()
        }
    }

    private func openMenu() {
        hideKeyboard()
        isMenuOpen = true
    }

    private func closeMenu() { isMenuOpen = false }

    /// Swipe from the left edge to open, swipe left to close.
    private var edgeDragGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                if !isMenuOpen, value.startLocation.x < 24, value.translation.width > 60 {
                    openMenu()
                } else if isMenuOpen, value.translation.width < -60 {
                    closeMenu()
                }
            }
    }
}

#Preview {
    ChatHomeView()
        .environmentObject(DIContainer.shared.authManager)
        .preferredColorScheme(.dark)
}
