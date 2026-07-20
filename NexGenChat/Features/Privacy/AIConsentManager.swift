import Foundation
import Combine

/// Tracks whether the user has granted permission to send their chat data to the
/// third-party AI provider (Apple guidelines 5.1.1(i) / 5.1.2(i)). Persisted in
/// `UserDefaults`; the chat flow blocks sending until consent is granted.
@MainActor
final class AIConsentManager: ObservableObject {
    @Published private(set) var hasConsented: Bool

    private let defaults: UserDefaults
    private let key = AppConstants.UserDefaultsKey.aiDataConsent

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasConsented = defaults.bool(forKey: key)
    }

    /// Record that the user agreed to share chat data with the AI provider.
    func grant() {
        hasConsented = true
        defaults.set(true, forKey: key)
    }

    /// Revoke consent (used from Settings). The next send re-prompts.
    func revoke() {
        hasConsented = false
        defaults.set(false, forKey: key)
    }
}
