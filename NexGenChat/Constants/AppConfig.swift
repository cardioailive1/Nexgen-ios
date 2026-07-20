import Foundation

/// Environment-level configuration. Swap `baseURL` per build configuration.
enum AppConfig {
    /// Base URL for the NexGen backend API. Replace with the real endpoint.
    static let baseURL = URL(string: "https://api.nexgenchat.example.com")!

    // MARK: - Supabase

    /// Supabase project — same account as the web app (`Cardio AI/Nexgen-ios`).
    /// Auth (sign in / sign up / session) and the `paid`/`plan` subscription
    /// state live here as GoTrue user metadata.
    static let supabaseURL = URL(string: "https://bvwgqafekmfqpylsrteu.supabase.co")!
    static let supabaseAnonKey = "sb_publishable_giKFkcglGwHs2ezDp0UsKQ_tmZ3QJis"

    /// GoTrue auth REST base (`/auth/v1`).
    static var supabaseAuthURL: URL { supabaseURL.appendingPathComponent("auth/v1") }

    // MARK: - Anthropic (chat)

    /// Chat streams directly from the Anthropic Messages API, same as the web
    /// app. The key is NOT hardcoded — it's loaded from an untracked
    /// `Secrets.plist` (key `AnthropicAPIKey`) so no secret lands in source.
    /// NOTE: a key shipped in a client binary is still extractable; mirror the
    /// web setup for now, move behind a proxy for production.
    static let anthropicAPIKey: String = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url),
              let key = dict["AnthropicAPIKey"] as? String,
              !key.isEmpty else {
            return ""
        }
        return key
    }()
    static let anthropicURL = URL(string: "https://api.anthropic.com/v1/messages")!
    static let anthropicVersion = "2023-06-01"
    static let chatMaxTokens = 4096

    /// Chat key strategy.
    /// `true`  → call Anthropic directly with the key in `Secrets.plist`.
    /// `false` → call the Supabase Edge Function proxy, which holds the key
    ///           server-side and authorizes each request by the user's JWT
    ///           (no API key shipped in the app — the production-safe path).
    static let useDirectAnthropicKey = true

    /// Supabase Edge Function that proxies chat to Anthropic (used when
    /// `useDirectAnthropicKey == false`). Deploy as a function named `chat`.
    static var chatProxyURL: URL {
        supabaseURL.appendingPathComponent("functions/v1/chat")
    }

    /// Supabase Edge Function that permanently deletes the signed-in user's
    /// account (Apple guideline 5.1.1(v)). Must run with the service-role key
    /// server-side; the client authorizes with the user's JWT. Deploy as a
    /// function named `delete-account`. Backend to be implemented.
    static var deleteAccountURL: URL {
        supabaseURL.appendingPathComponent("functions/v1/delete-account")
    }

    // MARK: - Third party AI (privacy disclosure)

    /// The third-party AI provider chat data is sent to. Surfaced in the consent
    /// gate and privacy policy (Apple guidelines 5.1.1(i) / 5.1.2(i)).
    static let aiProviderName = "Anthropic, PBC (the Claude API)"

    // MARK: - Legal

    /// Apple's standard Terms of Use (EULA). Used for the required functional
    /// EULA link in the subscription purchase flow (guideline 3.1.2(c)). If a
    /// custom EULA is adopted later, replace this URL and add it in App Store
    /// Connect.
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!


    /// Standard auto-renewable subscription terms, shown in the purchase flow.
    static let subscriptionTerms = "Payment is charged to your Apple Account at confirmation of purchase. Subscriptions renew automatically for the same price and period unless auto-renew is turned off at least 24 hours before the current period ends. Manage or cancel in your Apple Account settings."

    /// Base system prompt, mirroring the web app's `BASE_SYSTEM`.
    static let chatSystemPrompt = "You are NexGen Chat, a world-class AI assistant built by Corverxis Technologies. Write like a brilliant senior colleague — clear, direct, no padding. Use formatting only when it genuinely helps."

    /// Appended when "Explainable AI" is on, mirroring the web app's `XAI_SUFFIX`.
    static let xaiSuffix = """
    \n\nAFTER EVERY RESPONSE add this block:\n\n---\n**🧠 How I approached this**\n[2-4 sentences: reasoning process, information sources, structural choices]\n\n**⚖️ Confidence & caveats**\n[what you are confident about, what is uncertain, what to verify with a specialist]\n---\n\nKeep XAI brief for simple questions, thorough for complex ones.
    """

    /// Request timeout in seconds.
    static let requestTimeout: TimeInterval = 30

    /// Whether to log network traffic to the console (debug only).
    static let networkLoggingEnabled = true
}
