import SwiftUI

/// Email + password sign-in form.
struct SignInView: View {
    @StateObject var viewModel: LoginViewModel

    var body: some View {
        VStack(spacing: Spacing.lg) {
            CustomTextField(
                title: "Email",
                systemImage: "envelope.fill",
                text: $viewModel.email,
                keyboard: .emailAddress,
                contentType: .username,
                showError: viewModel.showEmailError
            )

            CustomSecureField(
                title: "Password",
                text: $viewModel.password,
                showError: viewModel.showPasswordError
            )

            HStack {
                Spacer()
                SecondaryButton(title: "Forgot password?") {
                    Task { await viewModel.forgotPassword() }
                }
            }

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error)
            }
            if let info = viewModel.infoMessage {
                InfoBanner(message: info)
            }

            PrimaryButton(
                title: "Sign In",
                isLoading: viewModel.isLoading,
                isEnabled: viewModel.isFormValid
            ) {
                Task { await viewModel.signIn() }
            }
            .padding(.top, Spacing.xs)
        }
        .cardSurface()
    }
}

/// Small inline error banner used across auth forms.
struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .font(AppFont.caption())
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(AppColor.danger)
        .padding(Spacing.md)
        .background(AppColor.danger.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
    }
}

/// Small inline success/info banner (mirrors `ErrorBanner`, accent-tinted).
struct InfoBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
            Text(message)
                .font(AppFont.caption())
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(AppColor.accent)
        .padding(Spacing.md)
        .background(AppColor.accent.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
    }
}

#Preview {
    ZStack {
        AppColor.background.ignoresSafeArea()
        SignInView(viewModel: DIContainer.shared.makeLoginViewModel())
            .padding()
    }
    .preferredColorScheme(.dark)
}
