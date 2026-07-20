import SwiftUI

@MainActor
final class SignupViewModel: ObservableObject {
    @Published var name = ""
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var agreedToTerms = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var showNameError = false
    @Published var showEmailError = false
    @Published var showPasswordError = false
    @Published var showConfirmError = false

    private let authManager: AuthenticationManager

    init(authManager: AuthenticationManager) {
        self.authManager = authManager
    }

    var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && FieldValidation.isValidEmail(email)
            && FieldValidation.isValidPassword(password)
            && passwordsMatch
            && agreedToTerms
    }

    func signUp() async {
        showNameError = name.trimmingCharacters(in: .whitespaces).isEmpty
        showEmailError = !FieldValidation.isValidEmail(email)
        showPasswordError = !FieldValidation.isValidPassword(password)
        showConfirmError = !passwordsMatch
        guard !showNameError, !showEmailError, !showPasswordError, !showConfirmError else { return }
        guard agreedToTerms else {
            errorMessage = "Please accept the Privacy Policy to continue."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authManager.signUp(name: name, email: email, password: password)
        } catch {
            errorMessage = (error as? NetworkError)?.errorDescription
                ?? error.localizedDescription
        }
    }
}
