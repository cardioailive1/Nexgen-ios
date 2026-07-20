import SwiftUI

/// One-time consent gate shown before the first message is sent to the
/// third-party AI provider. Discloses WHAT data is sent and WHO it is sent to,
/// and requires explicit permission (Apple guidelines 5.1.1(i) / 5.1.2(i)).
struct AIConsentView: View {
    /// Called when the user grants permission.
    let onAccept: () -> Void
    /// Called when the user declines (no data is sent).
    let onDecline: () -> Void
    /// Opens the full privacy policy.
    var onShowPrivacy: () -> Void = {}

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "lock.shield")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(AppColor.accent)
                .padding(.top, Spacing.xl)

            Text("Before you chat")
                .font(AppFont.title())
                .foregroundStyle(AppColor.text)

            Text("To answer your messages, \(AppConstants.appName) sends the content you provide to a third-party AI service.")
                .font(AppFont.callout())
                .foregroundStyle(AppColor.dim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: Spacing.md) {
                row(icon: "paperplane", title: "What is sent",
                    body: "The messages, images, and documents you choose to send in a conversation, plus your approximate locale for context.")
                row(icon: "building.2", title: "Who it is sent to",
                    body: "\(AppConfig.aiProviderName), on behalf of \(AppConstants.company), to generate responses. It is not sold or used to advertise to you.")
                row(icon: "hand.raised", title: "Your choice",
                    body: "You can decline and not use the assistant, and revoke this permission anytime in Settings.")
            }
            .padding(Spacing.lg)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))

            Button("Read our Privacy Policy") { onShowPrivacy() }
                .font(AppFont.caption())
                .foregroundStyle(AppColor.accent)
                .underline()

            Spacer(minLength: 0)

            PrimaryButton(title: "Agree & Continue", isLoading: false, isEnabled: true) {
                onAccept()
            }

            Button("Not now") { onDecline() }
                .font(AppFont.callout())
                .foregroundStyle(AppColor.muted)
                .padding(.bottom, Spacing.md)
        }
        .padding(.horizontal, Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.background.ignoresSafeArea())
        .interactiveDismissDisabled()
    }

    private func row(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColor.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.callout())
                    .foregroundStyle(AppColor.text)
                Text(body)
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    AIConsentView(onAccept: {}, onDecline: {})
        .preferredColorScheme(.dark)
}
