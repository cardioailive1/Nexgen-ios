import SwiftUI

/// The conversation history sidebar: brand header, new-chat button, search,
/// the conversation list, and a footer with the signed-in user + sign out.
struct ConversationsSidebarView: View {
    @StateObject var viewModel: ConversationsViewModel
    @EnvironmentObject private var authManager: AuthenticationManager
    let onSelectConversation: () -> Void
    /// Opens the Settings / account screen (Plans & Billing, delete account).
    var onOpenSettings: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
            list
            Divider().overlay(AppColor.lift)
            footer
        }
        .background(AppColor.surface.ignoresSafeArea())
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: Spacing.md) {
            NexGenLogoMark(size: 34)
            Text(AppConstants.appName)
                .font(AppFont.headline())
                .foregroundStyle(AppColor.text)
            Spacer()
            Button(action: viewModel.newChat) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColor.accent)
            }
        }
        .padding(Spacing.lg)
    }

    private var searchField: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColor.muted)
            TextField("Search…", text: $viewModel.search)
                .font(AppFont.callout())
                .foregroundStyle(AppColor.text)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm + 2)
        .background(AppColor.panel)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }

    private var list: some View {
        Group {
            if viewModel.filtered.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.xs) {
                        ForEach(viewModel.filtered) { convo in
                            ConversationRow(
                                conversation: convo,
                                isSelected: convo.id == viewModel.selectedID,
                                onSelect: {
                                    viewModel.select(convo.id)
                                    onSelectConversation()
                                },
                                onDelete: { viewModel.delete(convo.id) }
                            )
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 34))
                .foregroundStyle(AppColor.muted)
            Text(viewModel.search.isEmpty ? "No conversations yet" : "No matches")
                .font(AppFont.callout())
                .foregroundStyle(AppColor.dim)
        }
        .frame(maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: Spacing.md) {
            Button(action: onOpenSettings) {
                HStack(spacing: Spacing.md) {
                    Circle()
                        .fill(AppColor.accentGradient)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(initials)
                                .font(AppFont.caption())
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        )
                    VStack(alignment: .leading, spacing: 0) {
                        Text(userName)
                            .font(AppFont.callout())
                            .foregroundStyle(AppColor.text)
                            .lineLimit(1)
                        Text(userPlan)
                            .font(AppFont.caption())
                            .foregroundStyle(AppColor.muted)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .foregroundStyle(AppColor.muted)
            }
        }
        .padding(Spacing.lg)
    }

    // MARK: - Derived user info

    private var currentUser: UserEntity? {
        if case let .authenticated(user) = authManager.state { return user }
        return nil
    }

    private var userName: String { currentUser?.name ?? "Guest" }
    private var userPlan: String { (currentUser?.plan.rawValue ?? "free").capitalized + " plan" }
    private var initials: String {
        let parts = userName.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}

#Preview {
    let store = ConversationStore(conversations: [Conversation(title: "Trip plan"), Conversation(title: "Code review")])
    return ConversationsSidebarView(
        viewModel: ConversationsViewModel(store: store),
        onSelectConversation: {}
    )
    .environmentObject(DIContainer.shared.authManager)
    .preferredColorScheme(.dark)
}
