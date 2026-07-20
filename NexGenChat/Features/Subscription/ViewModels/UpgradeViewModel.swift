import SwiftUI
import Combine

/// Drives the upgrade wall. Wraps `SubscriptionManager` and exposes the two
/// presentation modes from the web app: a dismissible "change plan" sheet and a
/// blocking "subscription required" gate.
@MainActor
final class UpgradeViewModel: ObservableObject {

    /// Whether the wall is currently shown.
    @Published var isPresented = false
    /// Blocking mode hides the Close affordance and shows the required note.
    @Published private(set) var isBlocking = false

    let subscriptions: SubscriptionManager
    private var cancellable: AnyCancellable?

    init(subscriptions: SubscriptionManager) {
        self.subscriptions = subscriptions
        // Re-render the wall when the manager changes (isWorking, statusMessage,
        // products, currentPlan) — otherwise the view never reflects progress.
        cancellable = subscriptions.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    // MARK: - Copy (mirrors showUpgradeWall)

    var eyebrow: String { isBlocking ? "SUBSCRIPTION REQUIRED" : "CHANGE YOUR PLAN" }

    var headline: String {
        isBlocking ? "Choose a plan to get started" : "Switch plans anytime"
    }

    var subcopy: String {
        isBlocking
            ? "NexGen Chat requires an active subscription. Pick a plan below to continue."
            : "Stay on Flash, or upgrade to Pro or Ultra for more speed and quality."
    }

    var currentPlan: Plan? { subscriptions.currentPlan }
    var isWorking: Bool { subscriptions.isWorking }
    var statusMessage: String? { subscriptions.statusMessage }

    // MARK: - Presentation

    /// Show the dismissible "change plan" wall.
    func present() {
        isBlocking = false
        isPresented = true
    }

    /// Show the non-dismissible "subscription required" gate.
    func presentBlocking() {
        isBlocking = true
        isPresented = true
    }

    func dismiss() {
        guard !isBlocking else { return }
        isPresented = false
    }

    /// Clears the wall unconditionally — used once a subscription becomes active.
    func forceDismiss() {
        isBlocking = false
        isPresented = false
    }

    // MARK: - Actions

    func subscribe(to plan: Plan) {
        Task {
            await subscriptions.purchase(plan)
            if subscriptions.hasActiveSubscription, !isBlocking {
                isPresented = false
            } else if subscriptions.hasActiveSubscription, isBlocking {
                isBlocking = false
                isPresented = false
            }
        }
    }

    func restore() {
        Task { await subscriptions.restore() }
    }

    func displayPrice(for plan: Plan) -> String {
        subscriptions.displayPrice(for: plan)
    }

    func displayPeriod(for plan: Plan) -> String {
        subscriptions.displayPeriod(for: plan)
    }
}
