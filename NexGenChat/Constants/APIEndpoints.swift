import Foundation

/// Relative API paths, appended to `AppConfig.baseURL`.
enum APIEndpoints {
    enum Auth {
        static let signIn = "/auth/login"
        static let signUp = "/auth/register"
        static let refresh = "/auth/refresh"
        static let logout = "/auth/logout"
        static let mfaEnroll = "/auth/mfa/enroll"
        static let mfaVerify = "/auth/mfa/verify"
    }

    enum Chat {
        static let completions = "/chat/completions"
        static let conversations = "/chat/conversations"
    }
}
