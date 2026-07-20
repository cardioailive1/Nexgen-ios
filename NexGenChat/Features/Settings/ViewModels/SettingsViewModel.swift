import SwiftUI

/// Backs the Settings screen. Owns the account-deletion call and its transient
/// state (Apple guideline 5.1.1(v)).
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var showDeleteConfirm = false
    @Published var isDeleting = false
    @Published var deleteError: String?

    private let authManager: AuthenticationManager

    init(authManager: AuthenticationManager) {
        self.authManager = authManager
    }

    /// Permanently delete the account. On success `AuthenticationManager` clears
    /// the session, which returns the app to the sign-in screen.
    func deleteAccount() async {
        isDeleting = true
        deleteError = nil
        defer { isDeleting = false }
        do {
            try await authManager.deleteAccount()
        } catch {
            deleteError = (error as? NetworkError)?.errorDescription
                ?? error.localizedDescription
        }
    }
}
