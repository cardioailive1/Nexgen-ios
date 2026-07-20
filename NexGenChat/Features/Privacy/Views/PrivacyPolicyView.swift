import SwiftUI

/// Scrollable privacy policy, presented from the sign-up flow.
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text("Your privacy matters")
                        .font(AppFont.headline())
                        .foregroundStyle(AppColor.text)

                    ForEach(Self.sections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(section.title)
                                .font(AppFont.callout())
                                .foregroundStyle(AppColor.accent)
                            Text(section.body)
                                .font(AppFont.caption())
                                .foregroundStyle(AppColor.dim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(Spacing.xl)
            }
            .background(AppColor.background.ignoresSafeArea())
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private struct Section { let title: String; let body: String }

    private static let sections: [Section] = [
        .init(title: "What we collect",
              body: "Account details you provide (name, email), and the messages, images, and documents you send to the assistant so we can generate responses. We also derive your approximate locale to add context."),
        .init(title: "Third-party AI processing",
              body: "To generate responses, the content you send in a conversation is transmitted to \(AppConfig.aiProviderName), acting as our processor. Anthropic processes this data only to return a response and provides protections equivalent to those described here; it does not use your inputs to train its models or to advertise to you. We ask for your permission before any data is sent, and you can revoke it anytime in Settings."),
        .init(title: "How we use it",
              body: "To operate \(AppConstants.appName), respond to your messages, and keep your account secure. We do not sell your personal data."),
        .init(title: "Your controls",
              body: "You can export or delete your conversations at any time, revoke AI data sharing in Settings, and permanently delete your account and its data from Settings › Delete Account.")
    ]
}

#Preview {
    PrivacyPolicyView()
}
