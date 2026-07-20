import SwiftUI

/// Full-screen upgrade / subscription wall. Ports the web app's `.upgrade-wall`
/// modal — a blurred backdrop over a centered card with three plan tiles. Shows
/// either a dismissible "change plan" sheet or a blocking "subscription required"
/// gate, driven by `UpgradeViewModel`.
struct UpgradeWallView: View {
    @ObservedObject var viewModel: UpgradeViewModel
    @State private var showPrivacy = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            AppColor.background.opacity(0.95)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { viewModel.dismiss() }

            card
                .padding(20)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isPresented)
        .sheet(isPresented: $showPrivacy) { PrivacyPolicyView() }
    }

    private var card: some View {
        ScrollView(showsIndicators: false) {
        VStack(spacing: 0) {
            logo
                .padding(.bottom, 14)

            Text(viewModel.eyebrow)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(3)
                .foregroundStyle(AppColor.accent)
                .padding(.bottom, 8)

            Text(viewModel.headline)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppColor.text)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            Text(viewModel.subcopy)
                .font(.system(size: 13))
                .foregroundStyle(AppColor.dim)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            plans
                .padding(.vertical, 24)

            switchNote

            footer
        }
        .padding(36)
        }
        .frame(maxWidth: 580)
        .frame(maxHeight: 680)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(AppColor.lift, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.5), radius: 40, y: 20)
    }

    private var logo: some View {
        Image(systemName: "hexagon")
            .font(.system(size: 34, weight: .light))
            .foregroundStyle(AppColor.accent)
            .overlay {
                Circle()
                    .fill(AppColor.accent)
                    .frame(width: 5, height: 5)
            }
    }

    private var plans: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(Plan.allCases) { plan in
                PlanCardView(
                    plan: plan,
                    price: viewModel.displayPrice(for: plan),
                    period: viewModel.displayPeriod(for: plan),
                    isCurrent: viewModel.currentPlan == plan,
                    isHighlighted: (viewModel.currentPlan ?? .pro) == plan,
                    currentPlan: viewModel.currentPlan,
                    isBusy: viewModel.isWorking
                ) {
                    viewModel.subscribe(to: plan)
                }
            }
        }
    }

    /// Shown only when the user already subscribes: explains when a plan switch
    /// takes effect and that the App Store shows the exact adjusted amount at
    /// confirmation (iOS gives no proration API to compute it ourselves).
    @ViewBuilder
    private var switchNote: some View {
        if viewModel.currentPlan != nil {
            Text("Upgrades apply right away with a prorated credit; downgrades start at your next renewal. The App Store shows the exact adjusted amount before you confirm.")
                .font(.system(size: 10))
                .foregroundStyle(AppColor.dim)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 10) {
            if let status = viewModel.statusMessage {
                HStack(spacing: 6) {
                    if viewModel.isWorking { ProgressView().controlSize(.mini) }
                    Text(status)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppColor.dim)
                        .multilineTextAlignment(.center)
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            if !viewModel.isBlocking {
                Button("Close") { viewModel.dismiss() }
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(AppColor.accent)
                    .underline()
            }

            if viewModel.isBlocking {
                Text("A subscription is required to use NexGen Chat. Choose a plan above to continue.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AppColor.danger)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Restore Purchases") { viewModel.restore() }
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(AppColor.muted)
                .underline()

            legalBlock
                .padding(.top, 6)
        }
    }

    /// Required subscription disclosure + functional Terms of Use (EULA) and
    /// Privacy Policy links (guideline 3.1.2(c)).
    private var legalBlock: some View {
        VStack(spacing: 8) {
            Text(AppConfig.subscriptionTerms)
                .font(.system(size: 9))
                .foregroundStyle(AppColor.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 14) {
                Button("Terms of Use (EULA)") { openURL(AppConfig.termsOfUseURL) }
                Text("·").foregroundStyle(AppColor.muted)
                Button("Privacy Policy") { showPrivacy = true }
            }
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(AppColor.accent)
        }
    }
}

#Preview("Blocking") {
    let vm = UpgradeViewModel(subscriptions: SubscriptionManager())
    vm.presentBlocking()
    return UpgradeWallView(viewModel: vm)
        .preferredColorScheme(.dark)
}
