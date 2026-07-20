import SwiftUI
import StoreKit

/// Account, Plans & Billing, and Privacy settings. Surfaces the subscription
/// management and account-deletion flows Apple requires (guidelines 2.1(a) —
/// "Plans & Billing", 5.1.1(v) — account deletion, 5.1.2(i) — revoke AI sharing).
struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @ObservedObject private var subscriptions: SubscriptionManager
    @ObservedObject private var consent: AIConsentManager
    @EnvironmentObject private var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// Opens the upgrade wall to change plan (owned by the parent).
    let onChangePlan: () -> Void

    @State private var showPrivacy = false
    @State private var showManageSubscriptions = false

    init(authManager: AuthenticationManager,
         subscriptions: SubscriptionManager,
         consent: AIConsentManager,
         onChangePlan: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(authManager: authManager))
        self.subscriptions = subscriptions
        self.consent = consent
        self.onChangePlan = onChangePlan
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    accountHeader
                    billingSection
                    privacySection
                    accountSection
                    if let status = subscriptions.statusMessage {
                        Text(status)
                            .font(AppFont.caption())
                            .foregroundStyle(AppColor.dim)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(Spacing.lg)
            }
            .background(AppColor.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPrivacy) { PrivacyPolicyView() }
            .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
            .task { await subscriptions.refreshRenewalStatus() }
            .onChange(of: showManageSubscriptions) { _, showing in
                // Refresh once the system sheet closes — the user may have
                // cancelled or changed the plan there.
                if !showing { Task { await subscriptions.refreshRenewalStatus() } }
            }
            .alert("Delete account?", isPresented: $viewModel.showDeleteConfirm) {
                Button("Cancel Subscription First") {
                    // Alert dismisses first; present the system sheet next runloop
                    // so it isn't swallowed by the alert teardown.
                    DispatchQueue.main.async { showManageSubscriptions = true }
                }
                Button("Delete Account", role: .destructive) {
                    Task { await viewModel.deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your account and data and cannot be undone.\n\nDeleting your account does NOT cancel your subscription. To stop future charges, cancel it in Manage Subscription (Apple Account settings) before deleting.")
            }
            .alert("Couldn't delete account", isPresented: deleteErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.deleteError ?? "")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var accountHeader: some View {
        VStack(spacing: Spacing.sm) {
            Circle()
                .fill(AppColor.accentGradient)
                .frame(width: 56, height: 56)
                .overlay(
                    Text(initials).font(AppFont.headline()).fontWeight(.bold)
                        .foregroundStyle(.white)
                )
            Text(userName).font(AppFont.headline()).foregroundStyle(AppColor.text)
            Text(userEmail).font(AppFont.caption()).foregroundStyle(AppColor.dim)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.md)
    }

    private var billingSection: some View {
        card(title: "Plans & Billing") {
            infoRow(label: "Current plan", value: currentPlanName)
            if let renewal = renewalDetail {
                Divider().overlay(AppColor.lift)
                infoRow(label: renewal.label, value: renewal.value)
            }
            Divider().overlay(AppColor.lift)
            actionRow(icon: "arrow.up.right.square", title: "Change plan") {
                dismiss()
                onChangePlan()
            }
            Divider().overlay(AppColor.lift)
            actionRow(icon: "creditcard", title: "Manage Subscription") {
                showManageSubscriptions = true
            }
            Divider().overlay(AppColor.lift)
            actionRow(icon: "arrow.clockwise", title: "Restore Purchases") {
                Task { await subscriptions.restore() }
            }
        }
    }

    private var privacySection: some View {
        card(title: "Data & Privacy") {
            actionRow(icon: consent.hasConsented ? "checkmark.shield" : "shield.slash",
                      title: consent.hasConsented ? "AI data sharing: On" : "AI data sharing: Off",
                      trailing: consent.hasConsented ? "Turn off" : nil) {
                if consent.hasConsented { consent.revoke() }
            }
            Divider().overlay(AppColor.lift)
            actionRow(icon: "hand.raised", title: "Privacy Policy") { showPrivacy = true }
            Divider().overlay(AppColor.lift)
            actionRow(icon: "doc.text", title: "Terms of Use (EULA)") {
                openURL(AppConfig.termsOfUseURL)
            }
        }
    }

    private var accountSection: some View {
        card(title: "Account") {
            actionRow(icon: "rectangle.portrait.and.arrow.right", title: "Sign Out") {
                authManager.signOut()
            }
            Divider().overlay(AppColor.lift)
            Button {
                viewModel.showDeleteConfirm = true
            } label: {
                HStack(spacing: Spacing.md) {
                    if viewModel.isDeleting {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "trash").frame(width: 24)
                    }
                    Text("Delete Account")
                    Spacer()
                }
                .font(AppFont.callout())
                .foregroundStyle(AppColor.danger)
                .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isDeleting)
        }
    }

    // MARK: - Building blocks

    private func card<Content: View>(title: String,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(AppColor.muted)
                .padding(.leading, Spacing.sm)
            VStack(spacing: 0) { content() }
                .padding(.horizontal, Spacing.md)
                .background(AppColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(AppFont.callout()).foregroundStyle(AppColor.text)
            Spacer()
            Text(value).font(AppFont.callout()).foregroundStyle(AppColor.dim)
        }
        .padding(.vertical, Spacing.sm)
    }

    private func actionRow(icon: String, title: String, trailing: String? = nil,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon).frame(width: 24).foregroundStyle(AppColor.accent)
                Text(title).foregroundStyle(AppColor.text)
                Spacer()
                if let trailing {
                    Text(trailing).font(AppFont.caption()).foregroundStyle(AppColor.muted)
                } else {
                    Image(systemName: "chevron.right").font(.system(size: 12))
                        .foregroundStyle(AppColor.muted)
                }
            }
            .font(AppFont.callout())
            .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Derived user info

    private var deleteErrorBinding: Binding<Bool> {
        Binding(get: { viewModel.deleteError != nil },
                set: { if !$0 { viewModel.deleteError = nil } })
    }

    private var currentUser: UserEntity? {
        if case let .authenticated(user) = authManager.state { return user }
        return nil
    }

    private var userName: String { currentUser?.name ?? "Guest" }
    private var userEmail: String { currentUser?.email ?? "" }
    private var currentPlanName: String {
        if let plan = subscriptions.currentPlan { return plan.displayName + " plan" }
        return (currentUser?.plan.rawValue ?? "free").capitalized + " plan"
    }

    /// Renewal/expiry line for the billing card, derived from StoreKit status.
    /// `nil` when there is no active auto-renewable subscription to describe.
    private var renewalDetail: (label: String, value: String)? {
        guard let r = subscriptions.renewalState, let date = r.expirationDate else { return nil }
        let when = date.formatted(date: .abbreviated, time: .omitted)
        if r.hasBillingIssue { return ("Billing issue", "Retrying — update payment") }
        if let pending = r.pendingPlan { return ("Switches to \(pending.displayName)", when) }
        if r.willAutoRenew { return ("Renews", when) }
        return ("Expires (won't renew)", when)
    }
    private var initials: String {
        let parts = userName.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}

#Preview {
    SettingsView(
        authManager: DIContainer.shared.authManager,
        subscriptions: DIContainer.shared.subscriptionManager,
        consent: DIContainer.shared.aiConsentManager,
        onChangePlan: {}
    )
    .environmentObject(DIContainer.shared.authManager)
}
