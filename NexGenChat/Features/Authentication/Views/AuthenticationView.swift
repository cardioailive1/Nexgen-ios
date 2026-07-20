import SwiftUI

/// Auth flow host: brand header, a Sign In / Create Account segmented switcher,
/// and MFA presentation when the backend issues a challenge.
struct AuthenticationView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var selectedTab: AuthTab = .signIn
    @Namespace private var tabAnimation

    var body: some View {
        ZStack {
            AppColor.backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.xl) {
                    header
                    tabSwitcher

                    Group {
                        switch selectedTab {
                        case .signIn:
                            SignInView(viewModel: DIContainer.shared.makeLoginViewModel())
                        case .signUp:
                            CreateAccountView(viewModel: DIContainer.shared.makeSignupViewModel())
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.xxxl)
                .padding(.bottom, Spacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .animation(.easeInOut(duration: 0.25), value: selectedTab)
        .sheet(isPresented: mfaBinding) {
            if case let .mfaChallenge(challengeID) = authManager.state {
                MFAView(viewModel: DIContainer.shared.makeMFAViewModel(challengeID: challengeID))
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: Spacing.md) {
            NexGenLogoMark(size: 84)
            Text(AppConstants.appName)
                .font(AppFont.largeTitle())
                .foregroundStyle(AppColor.text)
            Text("AI chat, reimagined.")
                .font(AppFont.callout())
                .foregroundStyle(AppColor.dim)
        }
    }

    private var tabSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(AuthTab.allCases) { tab in
                let isSelected = tab == selectedTab
                Text(tab.rawValue)
                    .font(AppFont.callout())
                    .foregroundStyle(isSelected ? AppColor.text : AppColor.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .fill(AppColor.lift)
                                .matchedGeometryEffect(id: "authTab", in: tabAnimation)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) { selectedTab = tab }
                    }
            }
        }
        .padding(4)
        .background(AppColor.panel)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    private var mfaBinding: Binding<Bool> {
        Binding(
            get: {
                if case .mfaChallenge = authManager.state { return true }
                return false
            },
            set: { _ in }
        )
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(DIContainer.shared.authManager)
        .preferredColorScheme(.dark)
}
