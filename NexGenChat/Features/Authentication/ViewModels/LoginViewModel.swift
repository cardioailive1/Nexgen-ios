import SwiftUI

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showEmailError = false
    @Published var showPasswordError = false
    /// Non-error confirmation (e.g. "reset link sent").
    @Published var infoMessage: String?

    private let authManager: AuthenticationManager

    init(authManager: AuthenticationManager) {
        self.authManager = authManager
    }

    var isFormValid: Bool {
        FieldValidation.isValidEmail(email) && !password.isEmpty
    }

    func signIn() async {
        showEmailError = !FieldValidation.isValidEmail(email)
        showPasswordError = password.isEmpty
        guard !showEmailError, !showPasswordError else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authManager.signIn(email: email, password: password)
        } catch {
            errorMessage = (error as? NetworkError)?.errorDescription
                ?? error.localizedDescription
        }
    }

    /// Send a Supabase password-reset email to the entered address.
    func forgotPassword() async {
        infoMessage = nil
        errorMessage = nil
        guard FieldValidation.isValidEmail(email) else {
            showEmailError = true
            errorMessage = "Enter your email above first."
            return
        }
        do {
            try await authManager.resetPassword(email: email)
            infoMessage = "✓ Reset link sent — check your inbox."
        } catch {
            errorMessage = (error as? NetworkError)?.errorDescription
                ?? error.localizedDescription
        }
    }
}
