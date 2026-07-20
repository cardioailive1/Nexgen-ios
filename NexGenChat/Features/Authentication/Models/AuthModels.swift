import Foundation

// MARK: - Requests

struct SignInRequest: Encodable {
    let email: String
    let password: String
}

struct SignUpRequest: Encodable {
    let name: String
    let email: String
    let password: String
}

struct MFAVerifyRequest: Encodable {
    let code: String
    let challengeID: String
}

// MARK: - Internal auth response

/// Normalized auth result consumed by `AuthenticationManager`. When
/// `mfaRequired` is true the client must complete an MFA challenge before a
/// session is issued. Built from Supabase GoTrue responses by `AuthAPIService`.
struct AuthResponse {
    var token: String?
    var refreshToken: String?
    var user: UserEntity?
    var mfaRequired: Bool = false
    var challengeID: String?
    /// The verified TOTP factor to challenge/verify against when `mfaRequired`.
    var mfaFactorID: String?
}

// MARK: - Supabase GoTrue wire types

/// GoTrue token response (`/token`, `/signup` with autoconfirm) or session.
struct GoTrueSession: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let user: GoTrueUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

/// A GoTrue user. Subscription state lives in `user_metadata` (paid / plan).
/// `factors` is present on `/user` and lists enrolled MFA factors.
struct GoTrueUser: Decodable {
    let id: String
    let email: String?
    let userMetadata: UserMetadata?
    let factors: [GoTrueFactor]?

    enum CodingKeys: String, CodingKey {
        case id, email, factors
        case userMetadata = "user_metadata"
    }

    struct UserMetadata: Decodable {
        let fullName: String?
        let plan: String?
        let paid: Bool?

        enum CodingKeys: String, CodingKey {
            case fullName = "full_name"
            case plan, paid
        }
    }

    /// Map a GoTrue user into the app's domain model.
    func toEntity() -> UserEntity {
        let planTier = UserEntity.PlanTier(rawValue: userMetadata?.plan ?? "") ?? .free
        let displayName = userMetadata?.fullName
            ?? email?.split(separator: "@").first.map(String.init)
            ?? "You"
        return UserEntity(
            id: id,
            name: displayName,
            email: email ?? "",
            avatarURL: nil,
            plan: planTier,
            paid: userMetadata?.paid ?? false
        )
    }
}

/// An enrolled MFA factor (`/auth/v1/factors` / the `/user` `factors` array).
/// Only `totp` factors in `verified` status can gate sign-in.
struct GoTrueFactor: Decodable {
    let id: String
    let factorType: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case factorType = "factor_type"
    }

    var isVerifiedTOTP: Bool { factorType == "totp" && status == "verified" }
}

/// GoTrue challenge response (`POST /auth/v1/factors/{id}/challenge`).
struct GoTrueChallenge: Decodable {
    let id: String
}

/// GoTrue error body (`{ "error_description": "...", "msg": "..." }`).
struct GoTrueError: Decodable {
    let message: String?
    let errorDescription: String?
    let msg: String?

    enum CodingKeys: String, CodingKey {
        case message
        case errorDescription = "error_description"
        case msg
    }

    var displayMessage: String? { message ?? errorDescription ?? msg }
}

// MARK: - UI-facing types

/// Which auth screen is showing in the segmented header.
enum AuthTab: String, CaseIterable, Identifiable {
    case signIn = "Sign In"
    case signUp = "Create Account"
    var id: String { rawValue }
}

/// Lightweight validation results for form fields.
enum FieldValidation {
    static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    static func isValidPassword(_ password: String) -> Bool {
        password.count >= 8
    }
}
