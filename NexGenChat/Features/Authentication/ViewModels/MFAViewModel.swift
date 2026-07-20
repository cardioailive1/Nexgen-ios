import SwiftUI

@MainActor
final class MFAViewModel: ObservableObject {
    @Published var code = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    let challengeID: String
    private let authManager: AuthenticationManager

    init(challengeID: String, authManager: AuthenticationManager) {
        self.challengeID = challengeID
        self.authManager = authManager
    }

    var isCodeComplete: Bool { code.count == 6 }

    func verify() async {
        guard isCodeComplete else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authManager.verifyMFA(code: code, challengeID: challengeID)
        } catch {
            errorMessage = (error as? NetworkError)?.errorDescription
                ?? error.localizedDescription
            code = ""
        }
    }
}
