import Foundation
import Combine

/// Owns the authenticated session: persists Supabase (GoTrue) tokens, exposes
/// the current user, and drives the app's logged-in / logged-out state. The
/// user's `paid`/`plan` metadata is pushed into `SubscriptionManager`, which
/// gates the app.
@MainActor
final class AuthenticationManager: ObservableObject {

    enum SessionState: Equatable {
        case unauthenticated
        case authenticating
        case mfaChallenge(challengeID: String)
        case authenticated(UserEntity)
    }

    @Published private(set) var state: SessionState = .unauthenticated

    private let service: AuthAPIServicing
    private let keychain: KeychainHelper

    /// Set by `DIContainer` once both services exist. Receives the signed-in
    /// user's subscription state so the upgrade wall can gate the app.
    weak var subscriptions: SubscriptionManager?

    /// Interim state held between password sign-in and MFA verification: the
    /// factor to verify against and the AAL1 access token that authorizes it.
    private var pendingMFA: (factorID: String, accessToken: String, refreshToken: String?)?

    init(service: AuthAPIServicing = AuthAPIService(),
         keychain: KeychainHelper = .standard) {
        self.service = service
        self.keychain = keychain
        APIClient.shared.authTokenProvider = { [weak self] in
            self?.keychain.read(AppConstants.Keychain.authToken)
        }
    }

    var isAuthenticated: Bool {
        if case .authenticated = state { return true }
        return false
    }

    var currentUser: UserEntity? {
        if case let .authenticated(user) = state { return user }
        return nil
    }

    private var accessToken: String? {
        keychain.read(AppConstants.Keychain.authToken)
    }

    // MARK: - Actions

    func signIn(email: String, password: String) async throws {
        state = .authenticating
        do {
            let response = try await service.signIn(email: email, password: password)
            try handle(response)
        } catch {
            state = .unauthenticated
            throw error
        }
    }

    func signUp(name: String, email: String, password: String) async throws {
        state = .authenticating
        do {
            let response = try await service.signUp(name: name, email: email, password: password)
            guard response.token != nil else {
                // Email confirmation is on: no session yet. Ask the user to
                // confirm and sign in.
                state = .unauthenticated
                throw NetworkError.server(
                    status: 200,
                    message: "Check your email to confirm your account, then sign in."
                )
            }
            try handle(response)
        } catch {
            if case .authenticating = state { state = .unauthenticated }
            throw error
        }
    }

    func resetPassword(email: String) async throws {
        try await service.resetPassword(email: email)
    }

    func verifyMFA(code: String, challengeID: String) async throws {
        guard let pending = pendingMFA else {
            state = .unauthenticated
            throw NetworkError.invalidResponse
        }
        state = .authenticating
        do {
            let response = try await service.verifyMFA(
                factorID: pending.factorID, challengeID: challengeID,
                code: code, accessToken: pending.accessToken
            )
            pendingMFA = nil
            try handle(response)
        } catch {
            state = .mfaChallenge(challengeID: challengeID)
            throw error
        }
    }

    func signOut() {
        if let token = accessToken {
            Task { try? await service.signOut(accessToken: token) }
        }
        clearLocalSession()
    }

    /// Permanently delete the signed-in account, then clear the local session
    /// (Apple guideline 5.1.1(v)). Note: this does NOT cancel an active
    /// auto-renewable subscription — Apple bills those until the user cancels in
    /// their Apple Account settings; the UI warns about this before calling here.
    func deleteAccount() async throws {
        guard let token = accessToken else { throw NetworkError.unauthorized }
        try await service.deleteAccount(accessToken: token)
        clearLocalSession()
    }

    /// Restore a session from the stored refresh token on launch.
    func restoreSession() {
        guard let refresh = keychain.read(AppConstants.Keychain.refreshToken) else {
            state = .unauthenticated
            subscriptions?.applyServerState(plan: nil, paid: false)
            return
        }
        Task {
            do {
                let response = try await service.refreshSession(refreshToken: refresh)
                try handle(response)
            } catch {
                clearLocalSession()
            }
        }
    }

    /// Persist a newly purchased plan to Supabase (`paid: true`) after StoreKit
    /// confirms the purchase, keeping the backend the source of truth.
    func syncPlan(_ plan: Plan) async {
        guard let token = accessToken else { return }
        do {
            let user = try await service.updatePlan(plan.rawValue, paid: true, accessToken: token)
            state = .authenticated(user)
            subscriptions?.applyServerState(plan: user.plan.rawValue, paid: user.paid)
        } catch {
            // Optimistic: the StoreKit purchase already set currentPlan locally.
        }
    }

    // MARK: - Private

    private func handle(_ response: AuthResponse) throws {
        if response.mfaRequired, let challenge = response.challengeID,
           let factorID = response.mfaFactorID, let interim = response.token {
            // Hold the AAL1 token in memory (not the keychain — the session isn't
            // usable yet) so the MFA verify call can authorize against it.
            pendingMFA = (factorID, interim, response.refreshToken)
            state = .mfaChallenge(challengeID: challenge)
            return
        }
        guard let token = response.token, let user = response.user else {
            throw NetworkError.invalidResponse
        }
        keychain.save(token, for: AppConstants.Keychain.authToken)
        if let refresh = response.refreshToken {
            keychain.save(refresh, for: AppConstants.Keychain.refreshToken)
        }
        state = .authenticated(user)
        subscriptions?.applyServerState(plan: user.plan.rawValue, paid: user.paid)
    }

    private func clearLocalSession() {
        pendingMFA = nil
        keychain.delete(AppConstants.Keychain.authToken)
        keychain.delete(AppConstants.Keychain.refreshToken)
        state = .unauthenticated
        subscriptions?.applyServerState(plan: nil, paid: false)
    }
}
