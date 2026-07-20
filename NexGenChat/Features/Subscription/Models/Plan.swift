import SwiftUI

// MARK: - Subscription plan

/// The three paid subscription tiers. Mirrors the web app's Flash / Pro / Ultra
/// plans. There is no free tier — Flash ($9/mo) is the minimum plan.
enum Plan: String, CaseIterable, Identifiable, Codable {
    case flash, pro, ultra

    var id: String { rawValue }

    /// Map a StoreKit product identifier back to its plan.
    init?(productID: String) {
        guard let match = Plan.allCases.first(where: { $0.productID == productID }) else { return nil }
        self = match
    }

    /// App Store Connect product identifier (auto-renewable subscription).
    var productID: String {
        switch self {
        case .flash: return "com.W9464NC4J7.nexgenchat.flash.monthly"
        case .pro:   return "com.W9464NC4J7.nexgenchat.pro.monthly"
        case .ultra: return "com.W9464NC4J7.nexgenchat.ultra.monthly"
        }
    }

    var displayName: String {
        switch self {
        case .flash: return "Flash"
        case .pro:   return "Pro"
        case .ultra: return "Ultra"
        }
    }

    /// Fallback display price, used until StoreKit reports the localized price.
    var fallbackPrice: String {
        switch self {
        case .flash: return "$9"
        case .pro:   return "$15"
        case .ultra: return "$25"
        }
    }

    /// Two-line description shown on the plan card.
    var blurb: String {
        switch self {
        case .flash: return "NexGen Flash\n200K tokens/day"
        case .pro:   return "Faster, smarter NexGen Pro\n1M tokens/day"
        case .ultra: return "Maximum speed & quality\n5M tokens/day"
        }
    }

    var tint: Color {
        switch self {
        case .flash: return AppColor.flash
        case .pro:   return AppColor.pro
        case .ultra: return AppColor.ultra
        }
    }

    /// Ordering used for entitlement checks (higher = more access).
    var rank: Int {
        switch self {
        case .flash: return 0
        case .pro:   return 1
        case .ultra: return 2
        }
    }

    /// True when this plan grants access to `model`.
    func canUse(_ model: AIModel) -> Bool {
        rank >= model.requiredPlan.rank
    }
}

// MARK: - Model → plan gating

extension AIModel {
    /// The minimum plan required to use this model tier, mirroring the web app's
    /// `MODELS[m].plans` access lists.
    var requiredPlan: Plan {
        switch self {
        case .flash: return .flash   // plans: flash, pro, ultra
        case .pro:   return .pro     // plans: pro, ultra
        case .ultra: return .ultra   // plans: ultra
        }
    }
}
