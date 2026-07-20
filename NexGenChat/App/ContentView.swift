import SwiftUI

/// Root router. Chooses between splash, the auth flow, and the (placeholder)
/// authenticated experience based on session state.
struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authManager: AuthenticationManager

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            if appState.showSplash {
                SplashScreenView()
                    .transition(.opacity)
            } else {
                switch authManager.state {
                case .authenticated:
                    ChatHomeView()
                        .transition(.opacity)
                default:
                    AuthenticationView()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: appState.showSplash)
        .animation(.easeInOut(duration: 0.35), value: authManager.isAuthenticated)
        .onAppear {
            appState.bootstrap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation { appState.showSplash = false }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(DIContainer.shared.authManager)
}
