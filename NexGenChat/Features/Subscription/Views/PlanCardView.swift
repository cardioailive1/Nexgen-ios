import SwiftUI

/// A single plan tile inside the upgrade wall (Flash / Pro / Ultra).
struct PlanCardView: View {
    let plan: Plan
    let price: String
    /// Real billing period from StoreKit ("/mo", "/yr"), so the label matches the
    /// actual charge period (guideline 3.1.2(c)).
    let period: String
    let isCurrent: Bool
    /// Visually emphasized tile (accent border, filled CTA). The wall highlights
    /// the subscribed plan, or Pro by default when nothing is subscribed.
    let isHighlighted: Bool
    /// The user's active plan, if any — drives Upgrade/Downgrade CTA wording.
    let currentPlan: Plan?
    let isBusy: Bool
    let onSubscribe: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if isHighlighted && !isCurrent {
                Text("POPULAR")
                    .font(.system(size: 7, weight: .semibold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(AppColor.accent)
            }

            Text(plan.displayName.uppercased())
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(AppColor.muted)

            priceLabel

            Text(plan.blurb)
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColor.muted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            subscribeButton
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 10)
        .background(AppColor.background)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(isHighlighted ? AppColor.accent : AppColor.lift,
                        lineWidth: isHighlighted ? 2 : 1)
        }
    }

    private var priceLabel: some View {
        HStack(alignment: .lastTextBaseline, spacing: 1) {
            Text(price)
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(plan.tint)
            Text(period)
                .font(.system(size: 11))
                .foregroundStyle(AppColor.muted)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var subscribeButton: some View {
        Button(action: onSubscribe) {
            Group {
                if isBusy {
                    ProgressView().controlSize(.mini)
                } else {
                    Text(ctaLabel)
                }
            }
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(buttonBackground)
            .foregroundStyle(buttonForeground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .overlay {
                if !isHighlighted {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .stroke(AppColor.lift, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isBusy || isCurrent)
    }

    /// "Current plan" for the active tier; "Upgrade"/"Downgrade" when the user
    /// already subscribes to a different tier (a plan switch); else "Subscribe".
    private var ctaLabel: String {
        if isCurrent { return "Current plan" }
        guard let current = currentPlan else { return "Subscribe" }
        return plan.rank > current.rank ? "Upgrade" : "Downgrade"
    }

    private var buttonBackground: Color {
        if isCurrent { return AppColor.panel }
        return isHighlighted ? AppColor.accent : .clear
    }

    private var buttonForeground: Color {
        if isCurrent { return AppColor.muted }
        return isHighlighted ? .white : AppColor.dim
    }
}

#Preview {
    ZStack {
        AppColor.surface.ignoresSafeArea()
        HStack(spacing: 12) {
            PlanCardView(plan: .flash, price: "$9", period: "/mo", isCurrent: true, isHighlighted: true, currentPlan: .flash, isBusy: false) {}
            PlanCardView(plan: .pro, price: "$15", period: "/mo", isCurrent: false, isHighlighted: false, currentPlan: .flash, isBusy: false) {}
            PlanCardView(plan: .ultra, price: "$25", period: "/mo", isCurrent: false, isHighlighted: false, currentPlan: .flash, isBusy: false) {}
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
