import SwiftUI

/// Six-digit one-time-code entry shown when the backend requires MFA.
struct MFAView: View {
    @StateObject var viewModel: MFAViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var codeFocused: Bool

    var body: some View {
        ZStack {
            AppColor.backgroundGradient.ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(AppColor.accent)
                    Text("Verify it's you")
                        .font(AppFont.title())
                        .foregroundStyle(AppColor.text)
                    Text("Enter the 6-digit code from your authenticator app.")
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.dim)
                        .multilineTextAlignment(.center)
                }

                codeBoxes

                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error)
                }

                PrimaryButton(
                    title: "Verify",
                    isLoading: viewModel.isLoading,
                    isEnabled: viewModel.isCodeComplete
                ) {
                    Task { await viewModel.verify() }
                }
            }
            .padding(Spacing.xl)
        }
        .onAppear { codeFocused = true }
    }

    private var codeBoxes: some View {
        ZStack {
            // Hidden field that actually captures input.
            TextField("", text: $viewModel.code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($codeFocused)
                .opacity(0.001)
                .onChange(of: viewModel.code) { _, newValue in
                    viewModel.code = String(newValue.prefix(6).filter(\.isNumber))
                }

            HStack(spacing: Spacing.md) {
                ForEach(0..<6, id: \.self) { index in
                    digitBox(at: index)
                }
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { codeFocused = true }
    }

    private func digitBox(at index: Int) -> some View {
        let chars = Array(viewModel.code)
        let value = index < chars.count ? String(chars[index]) : ""
        let isActive = index == chars.count

        return Text(value)
            .font(AppFont.title())
            .foregroundStyle(AppColor.text)
            .frame(width: 44, height: 56)
            .background(AppColor.panel)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .strokeBorder(isActive ? AppColor.accent : AppColor.lift, lineWidth: 1.5)
            )
    }
}

#Preview {
    MFAView(viewModel: DIContainer.shared.makeMFAViewModel(challengeID: "preview"))
        .preferredColorScheme(.dark)
}
