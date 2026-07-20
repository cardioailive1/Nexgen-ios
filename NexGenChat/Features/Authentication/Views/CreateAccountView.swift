import SwiftUI

/// New-account registration form with terms acceptance.
struct CreateAccountView: View {
    @StateObject var viewModel: SignupViewModel
    @State private var showPrivacy = false

    var body: some View {
        VStack(spacing: Spacing.lg) {
            CustomTextField(
                title: "Full Name",
                systemImage: "person.fill",
                text: $viewModel.name,
                contentType: .name,
                autocapitalization: .words,
                showError: viewModel.showNameError
            )

            CustomTextField(
                title: "Email",
                systemImage: "envelope.fill",
                text: $viewModel.email,
                keyboard: .emailAddress,
                contentType: .username,
                showError: viewModel.showEmailError
            )

            CustomSecureField(
                title: "Password (min 8 characters)",
                text: $viewModel.password,
                contentType: .newPassword,
                showError: viewModel.showPasswordError
            )

            CustomSecureField(
                title: "Confirm Password",
                text: $viewModel.confirmPassword,
                contentType: .newPassword,
                showError: viewModel.showConfirmError
            )

            termsRow

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error)
            }

            PrimaryButton(
                title: "Create Account",
                isLoading: viewModel.isLoading,
                isEnabled: viewModel.isFormValid
            ) {
                Task { await viewModel.signUp() }
            }
            .padding(.top, Spacing.xs)
        }
        .cardSurface()
        .sheet(isPresented: $showPrivacy) {
            PrivacyPolicyView()
        }
    }

    private var termsRow: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Button {
                viewModel.agreedToTerms.toggle()
            } label: {
                Image(systemName: viewModel.agreedToTerms ? "checkmark.square.fill" : "square")
                    .foregroundStyle(viewModel.agreedToTerms ? AppColor.accent : AppColor.muted)
                    .font(.system(size: 20))
            }

            (
                Text("I agree to the ")
                    .foregroundColor(AppColor.dim)
                + Text("Privacy Policy")
                    .foregroundColor(AppColor.accent)
                    .underline()
            )
            .font(AppFont.caption())
            .onTapGesture { showPrivacy = true }

            Spacer(minLength: 0)
        }
    }
}

#Preview {
    ZStack {
        AppColor.background.ignoresSafeArea()
        CreateAccountView(viewModel: DIContainer.shared.makeSignupViewModel())
            .padding()
    }
    .preferredColorScheme(.dark)
}
