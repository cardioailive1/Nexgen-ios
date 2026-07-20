import SwiftUI

@main
struct NexGenChatApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(appState.authManager)
                .preferredColorScheme(.dark)
                .tint(AppColor.accent)
        }
    }
}
