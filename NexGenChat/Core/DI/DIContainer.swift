import Foundation

/// Central composition root. Constructs shared services and hands them to
/// view models. Keeps concrete types out of the views.
@MainActor
final class DIContainer {
    static let shared = DIContainer()

    let apiClient: APIClientProtocol
    let authService: AuthAPIServicing
    let authManager: AuthenticationManager
    let chatService: ChatServicing
    let conversationStore: ConversationStore
    let subscriptionManager: SubscriptionManager
    let geoContextProvider: GeoContextProvider
    let aiConsentManager: AIConsentManager

    private init() {
        self.apiClient = APIClient.shared
        self.authService = AuthAPIService()
        self.authManager = AuthenticationManager(service: authService)
        self.conversationStore = ConversationStore()
        self.subscriptionManager = SubscriptionManager()
        self.geoContextProvider = GeoContextProvider()
        self.aiConsentManager = AIConsentManager()
        // Direct mode needs a key in Secrets.plist; without one, fall back to the
        // mock streamer so the app stays runnable. Proxy mode never ships a key,
        // so it always uses the live service. The live service injects the geo/
        // weather context into the system prompt (same as the web app).
        let geo = geoContextProvider
        let directWithoutKey = AppConfig.useDirectAnthropicKey
            && AppConfig.anthropicAPIKey.isEmpty
        self.chatService = directWithoutKey
            ? MockChatService()
            : ChatAPIService(geoContext: { geo.context })

        // Supabase is the subscription source of truth: the signed-in user's
        // paid/plan metadata drives the gate, and StoreKit purchases sync back.
        authManager.subscriptions = subscriptionManager
        subscriptionManager.planSyncHandler = { [authManager] plan in
            await authManager.syncPlan(plan)
        }
    }

    // MARK: - View model factories

    func makeLoginViewModel() -> LoginViewModel {
        LoginViewModel(authManager: authManager)
    }

    func makeSignupViewModel() -> SignupViewModel {
        SignupViewModel(authManager: authManager)
    }

    func makeMFAViewModel(challengeID: String) -> MFAViewModel {
        MFAViewModel(challengeID: challengeID, authManager: authManager)
    }

    func makeChatViewModel(upgradeViewModel: UpgradeViewModel) -> ChatViewModel {
        ChatViewModel(store: conversationStore,
                      service: chatService,
                      subscriptions: subscriptionManager,
                      upgrade: upgradeViewModel,
                      consent: aiConsentManager)
    }

    func makeConversationsViewModel() -> ConversationsViewModel {
        ConversationsViewModel(store: conversationStore)
    }

    func makeUpgradeViewModel() -> UpgradeViewModel {
        UpgradeViewModel(subscriptions: subscriptionManager)
    }
}
