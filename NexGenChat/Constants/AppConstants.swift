import Foundation

/// Static, non-environment app constants.
enum AppConstants {
    static let appName = "NexGen Chat"
    static let company = "Corverxis Technologies"
    static let bundleID = "com.W9464NC4J7.nexgenchat"

    /// Keychain service identifier for stored credentials/tokens.
    static let keychainService = "com.W9464NC4J7.nexgenchat.keychain"

    enum Keychain {
        static let authToken = "auth_token"
        static let refreshToken = "refresh_token"
    }

    enum UserDefaultsKey {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let selectedModel = "selectedModel"
        /// User granted permission to send chat data to the third-party AI
        /// provider (guidelines 5.1.1(i) / 5.1.2(i)).
        static let aiDataConsent = "aiDataConsent"
    }
}
