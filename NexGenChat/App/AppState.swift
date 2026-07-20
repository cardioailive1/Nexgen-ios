import SwiftUI

/// Top-level observable app state shared through the environment.
/// Wraps the auth manager and any global UI flags.
@MainActor
final class AppState: ObservableObject {
    @Published var authManager: AuthenticationManager
    @Published var showSplash: Bool = true

    init(authManager: AuthenticationManager = DIContainer.shared.authManager) {
        self.authManager = authManager
    }

    func bootstrap() {
        authManager.restoreSession()
        // Build the live location/weather context for the chat system prompt
        // (mirrors the web app's initGeoContext on load).
        Task { await DIContainer.shared.geoContextProvider.refresh() }
    }
}
