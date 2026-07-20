import Foundation
import StoreKit

/// Owns subscription state. The **source of truth is Supabase** user metadata
/// (`paid`/`plan`), pushed in via `applyServerState` on sign-in — matching the
/// web app. StoreKit 2 drives the actual purchase; on success the plan is synced
/// back to Supabase (`planSyncHandler`) so it persists across devices.
///
/// Replaces the web app's `CdvPurchase` (cordova-plugin-purchase) flow with the
/// native StoreKit 2 API. Product identifiers match App Store Connect.
@MainActor
final class SubscriptionManager: ObservableObject {

    /// The user's active plan, or `nil` when no subscription is active.
    @Published private(set) var currentPlan: Plan?
    /// StoreKit products keyed by plan, once loaded from the App Store.
    @Published private(set) var products: [Plan: Product] = [:]
    /// A purchase or restore is in flight.
    @Published private(set) var isWorking = false
    /// Transient user-facing message (purchase failures, restore results).
    @Published var statusMessage: String?
    /// True once the signed-in user's Supabase subscription state has been
    /// applied. Until then callers should not gate on `currentPlan` (avoids
    /// flashing the wall before we know whether the user is subscribed).
    @Published private(set) var hasResolvedEntitlements = false
    /// Renewal details for the active subscription, read from StoreKit. `nil`
    /// when there is no active auto-renewable subscription on this Apple Account.
    @Published private(set) var renewalState: RenewalState?

    /// Renewal snapshot surfaced in Settings (renewal date, auto-renew, pending
    /// plan switch). Sourced from `Product.SubscriptionInfo.Status`.
    struct RenewalState {
        let plan: Plan
        /// Next renewal date (when auto-renewing) or expiry date (when off).
        let expirationDate: Date?
        let willAutoRenew: Bool
        /// A plan the subscription is scheduled to switch to at next renewal
        /// (a queued downgrade), if different from the current plan.
        let pendingPlan: Plan?
        /// The subscription is in billing retry — the last renewal charge failed.
        let hasBillingIssue: Bool
    }

    /// Persists a purchased plan to the backend (Supabase). Wired by `DIContainer`
    /// to `AuthenticationManager.syncPlan`.
    var planSyncHandler: ((Plan) async -> Void)?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = listenForTransactions()
        Task { await loadProducts() }
    }

    deinit { updatesTask?.cancel() }

    var hasActiveSubscription: Bool { currentPlan != nil }

    // MARK: - Server state (source of truth)

    /// Apply the signed-in user's Supabase subscription metadata. `paid == false`
    /// (or a missing plan) means no active subscription → the app is gated.
    func applyServerState(plan: String?, paid: Bool) {
        currentPlan = paid ? plan.flatMap(Plan.init(rawValue:)) : nil
        hasResolvedEntitlements = true
    }

    /// Localized price for a plan if StoreKit has loaded it, else the fallback.
    func displayPrice(for plan: Plan) -> String {
        products[plan]?.displayPrice ?? plan.fallbackPrice
    }

    /// The subscription's real billing period label ("/mo", "/6 mo", "/yr"),
    /// read from StoreKit so the shown period always matches the actual charge
    /// period configured in App Store Connect (guideline 3.1.2(c)). The
    /// `displayPrice` above is the full amount billed for exactly this period.
    func displayPeriod(for plan: Plan) -> String {
        guard let period = products[plan]?.subscription?.subscriptionPeriod else {
            return "/mo"
        }
        let n = period.value
        switch period.unit {
        case .day:   return n == 1 ? "/day" : "/\(n) days"
        case .week:  return n == 1 ? "/wk" : "/\(n) wks"
        case .month: return n == 1 ? "/mo" : "/\(n) mo"
        case .year:  return n == 1 ? "/yr" : "/\(n) yrs"
        @unknown default: return ""
        }
    }

    // MARK: - Products

    func loadProducts() async {
        do {
            let ids = Plan.allCases.map(\.productID)
            let fetched = try await Product.products(for: ids)
            var mapped: [Plan: Product] = [:]
            for product in fetched {
                if let plan = Plan.allCases.first(where: { $0.productID == product.id }) {
                    mapped[plan] = product
                }
            }
            products = mapped
            await refreshRenewalStatus()
        } catch {
            // Non-fatal: the wall still renders with fallback prices.
            statusMessage = "Couldn't load plans — check your connection."
        }
    }

    // MARK: - Renewal status

    /// Refresh `renewalState` from StoreKit's subscription-group status. Safe to
    /// call repeatedly (e.g. on Settings appear, after a purchase/restore).
    func refreshRenewalStatus() async {
        // `status` covers the whole subscription group, so any product with a
        // `subscription` payload works as the query entry point.
        guard let sub = products.values.compactMap(\.subscription).first,
              let statuses = try? await sub.status else {
            renewalState = nil
            return
        }
        for status in statuses {
            guard [.subscribed, .inGracePeriod, .inBillingRetryPeriod].contains(status.state),
                  case .verified(let txn) = status.transaction,
                  case .verified(let renewal) = status.renewalInfo,
                  let plan = Plan(productID: txn.productID) else { continue }
            let pending = renewal.autoRenewPreference.flatMap { Plan(productID: $0) }
            renewalState = RenewalState(
                plan: plan,
                expirationDate: txn.expirationDate,
                willAutoRenew: renewal.willAutoRenew,
                pendingPlan: (pending != nil && pending != plan) ? pending : nil,
                hasBillingIssue: status.state == .inBillingRetryPeriod
            )
            return
        }
        renewalState = nil
    }

    // MARK: - Purchase

    func purchase(_ plan: Plan) async {
        isWorking = true
        defer { isWorking = false }

        // Products may not have loaded yet (StoreKit config inactive, slow
        // network). Retry a load inline before giving up so tapping Subscribe
        // does something visible.
        var product = products[plan]
        if product == nil {
            statusMessage = "Loading plans…"
            await loadProducts()
            product = products[plan]
        }
        guard let product else {
            statusMessage = "Plan unavailable — make sure the StoreKit config is active (run from Xcode) or try again."
            return
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                // Optimistically reflect the purchase, then persist to Supabase.
                currentPlan = plan
                hasResolvedEntitlements = true
                await planSyncHandler?(plan)
                await refreshRenewalStatus()
                statusMessage = "✓ You're on \(plan.displayName)"
            case .userCancelled:
                break
            case .pending:
                statusMessage = "Purchase pending approval."
            @unknown default:
                break
            }
        } catch {
            statusMessage = "Purchase failed — contact support@corverxis.com"
        }
    }

    // MARK: - Restore

    func restore() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await AppStore.sync()
            if let plan = await activeEntitlement() {
                currentPlan = plan
                hasResolvedEntitlements = true
                await planSyncHandler?(plan)
                await refreshRenewalStatus()
                statusMessage = "✓ Purchases restored"
            } else {
                statusMessage = "No active subscription found."
            }
        } catch {
            statusMessage = "Restore failed — contact support@corverxis.com"
        }
    }

    // MARK: - Entitlements

    /// The highest-tier active StoreKit entitlement, if any.
    private func activeEntitlement() async -> Plan? {
        var best: Plan?
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            guard transaction.revocationDate == nil else { continue }
            if let plan = Plan(productID: transaction.productID) {
                if best == nil || plan.rank > best!.rank { best = plan }
            }
        }
        return best
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { continue }
                if let transaction = try? await self.checkVerified(result) {
                    await transaction.finish()
                    if let plan = await self.activeEntitlement() {
                        self.currentPlan = plan
                        self.hasResolvedEntitlements = true
                        await self.planSyncHandler?(plan)
                        await self.refreshRenewalStatus()
                    }
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreError.failedVerification
        }
    }

    enum StoreError: Error { case failedVerification }
}
