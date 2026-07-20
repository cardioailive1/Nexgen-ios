import Foundation

/// Auth against Supabase GoTrue (`/auth/v1`). Uses the same project as the web
/// app, so accounts, passwords, and the `paid`/`plan` subscription metadata are
/// shared. Talks to GoTrue directly (own URLSession) rather than through
/// `APIClient`, because it needs the Supabase host, the `apikey` header, and
/// GoTrue's response/error shapes.
protocol AuthAPIServicing {
    func signIn(email: String, password: String) async throws -> AuthResponse
    func signUp(name: String, email: String, password: String) async throws -> AuthResponse
    func refreshSession(refreshToken: String) async throws -> AuthResponse
    /// Verify a TOTP code against a challenge, upgrading the session to AAL2.
    /// `accessToken` is the interim (AAL1) token issued by password sign-in.
    func verifyMFA(factorID: String, challengeID: String, code: String,
                   accessToken: String) async throws -> AuthResponse
    /// Persist the chosen plan to Supabase user metadata (`paid`/`plan`).
    func updatePlan(_ plan: String, paid: Bool, accessToken: String) async throws -> UserEntity
    func resetPassword(email: String) async throws
    func signOut(accessToken: String) async throws
    /// Permanently delete the signed-in user's account and its data (Apple
    /// guideline 5.1.1(v)). Runs against a server-side function that holds the
    /// service-role key; the client authorizes with the user's JWT.
    func deleteAccount(accessToken: String) async throws
}

final class AuthAPIService: AuthAPIServicing {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    // MARK: - Sign in / up

    func signIn(email: String, password: String) async throws -> AuthResponse {
        let body = try JSONSerialization.data(withJSONObject: [
            "email": email, "password": password
        ])
        let gotrue: GoTrueSession = try await perform(
            path: "token", query: [.init(name: "grant_type", value: "password")],
            method: "POST", body: body
        )
        // Password sign-in yields an AAL1 session. If the account has a verified
        // TOTP factor, GoTrue requires stepping up to AAL2 before the session is
        // usable — create a challenge and hand the client back to the MFA screen.
        if let token = gotrue.accessToken,
           let factor = try await verifiedTOTPFactor(accessToken: token) {
            let challengeID = try await challenge(factorID: factor.id, accessToken: token)
            return AuthResponse(
                token: gotrue.accessToken,
                refreshToken: gotrue.refreshToken,
                user: gotrue.user?.toEntity(),
                mfaRequired: true,
                challengeID: challengeID,
                mfaFactorID: factor.id
            )
        }
        return authResponse(from: gotrue)
    }

    func signUp(name: String, email: String, password: String) async throws -> AuthResponse {
        let metadata: [String: Any] = [
            "full_name": name,
            "pending_plan": "flash",
            "paid": false,
            "privacy_agreed": true,
            "privacy_agreed_at": ISO8601DateFormatter().string(from: Date()),
            "privacy_version": "1.0"
        ]
        let body = try JSONSerialization.data(withJSONObject: [
            "email": email, "password": password, "data": metadata
        ])
        let gotrue: GoTrueSession = try await perform(
            path: "signup", method: "POST", body: body
        )
        return authResponse(from: gotrue)
    }

    func refreshSession(refreshToken: String) async throws -> AuthResponse {
        let body = try JSONSerialization.data(withJSONObject: [
            "refresh_token": refreshToken
        ])
        let gotrue: GoTrueSession = try await perform(
            path: "token", query: [.init(name: "grant_type", value: "refresh_token")],
            method: "POST", body: body
        )
        return authResponse(from: gotrue)
    }

    func verifyMFA(factorID: String, challengeID: String, code: String,
                   accessToken: String) async throws -> AuthResponse {
        let body = try JSONSerialization.data(withJSONObject: [
            "challenge_id": challengeID, "code": code
        ])
        let gotrue: GoTrueSession = try await perform(
            path: "factors/\(factorID)/verify", method: "POST",
            body: body, accessToken: accessToken
        )
        return authResponse(from: gotrue)
    }

    // MARK: - MFA helpers

    /// Look up the account's first verified TOTP factor, if any, via `/user`.
    private func verifiedTOTPFactor(accessToken: String) async throws -> GoTrueFactor? {
        let user: GoTrueUser = try await perform(
            path: "user", method: "GET", accessToken: accessToken
        )
        return user.factors?.first(where: \.isVerifiedTOTP)
    }

    /// Create a TOTP challenge and return its id (used as `challenge_id`).
    private func challenge(factorID: String, accessToken: String) async throws -> String {
        let challenge: GoTrueChallenge = try await perform(
            path: "factors/\(factorID)/challenge", method: "POST",
            accessToken: accessToken
        )
        return challenge.id
    }

    // MARK: - Plan sync

    func updatePlan(_ plan: String, paid: Bool, accessToken: String) async throws -> UserEntity {
        let body = try JSONSerialization.data(withJSONObject: [
            "data": ["plan": plan, "paid": paid]
        ])
        let user: GoTrueUser = try await perform(
            path: "user", method: "PUT", body: body, accessToken: accessToken
        )
        return user.toEntity()
    }

    // MARK: - Password reset / sign out

    func resetPassword(email: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["email": email])
        try await performVoid(path: "recover", method: "POST", body: body)
    }

    func signOut(accessToken: String) async throws {
        try await performVoid(path: "logout", method: "POST", accessToken: accessToken)
    }

    func deleteAccount(accessToken: String) async throws {
        // Targets a Supabase Edge Function (not the GoTrue base URL), so it can't
        // reuse `request(...)`. The function verifies the JWT and deletes the user
        // with the service-role key server-side.
        var req = URLRequest(url: AppConfig.deleteAccountURL,
                             timeoutInterval: AppConfig.requestTimeout)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw NetworkError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let message = (try? decoder.decode(GoTrueError.self, from: data))?.displayMessage
            throw NetworkError.server(status: http.statusCode, message: message)
        }
    }

    // MARK: - Mapping

    private func authResponse(from session: GoTrueSession) -> AuthResponse {
        AuthResponse(
            token: session.accessToken,
            refreshToken: session.refreshToken,
            user: session.user?.toEntity(),
            mfaRequired: false,
            challengeID: nil
        )
    }

    // MARK: - Networking

    private func perform<T: Decodable>(
        path: String,
        query: [URLQueryItem] = [],
        method: String,
        body: Data? = nil,
        accessToken: String? = nil
    ) async throws -> T {
        let data = try await request(path: path, query: query, method: method,
                                     body: body, accessToken: accessToken)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decoding
        }
    }

    private func performVoid(
        path: String,
        method: String,
        body: Data? = nil,
        accessToken: String? = nil
    ) async throws {
        _ = try await request(path: path, query: [], method: method,
                              body: body, accessToken: accessToken)
    }

    private func request(
        path: String,
        query: [URLQueryItem],
        method: String,
        body: Data?,
        accessToken: String?
    ) async throws -> Data {
        var components = URLComponents(
            url: AppConfig.supabaseAuthURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw NetworkError.invalidURL }

        var req = URLRequest(url: url, timeoutInterval: AppConfig.requestTimeout)
        req.httpMethod = method
        req.httpBody = body
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        let bearer = accessToken ?? AppConfig.supabaseAnonKey
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw NetworkError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            return data
        default:
            // GoTrue returns a descriptive JSON error body — surface it.
            if let apiError = try? decoder.decode(GoTrueError.self, from: data),
               let message = apiError.displayMessage {
                throw NetworkError.server(status: http.statusCode, message: message)
            }
            throw NetworkError.server(status: http.statusCode, message: nil)
        }
    }
}
