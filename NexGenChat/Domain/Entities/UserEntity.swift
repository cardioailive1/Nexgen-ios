import Foundation

/// The authenticated user domain model.
struct UserEntity: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let email: String
    var avatarURL: URL?
    var plan: PlanTier
    /// Mirrors Supabase `user_metadata.paid` — the subscription source of truth.
    var paid: Bool = false

    enum PlanTier: String, Codable, CaseIterable {
        case free, flash, pro, ultra
    }
}

extension UserEntity {
    /// Placeholder used for previews and pre-auth states.
    static let placeholder = UserEntity(
        id: "preview",
        name: "Alex Rivera",
        email: "alex@nexgen.app",
        avatarURL: nil,
        plan: .pro
    )
}
