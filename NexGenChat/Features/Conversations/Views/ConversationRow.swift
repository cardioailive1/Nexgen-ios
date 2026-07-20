import SwiftUI

/// A single conversation entry in the sidebar list.
struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.md) {
                Image(systemName: conversation.model.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(conversation.model.tint)
                    .frame(width: 26, height: 26)
                    .background(conversation.model.tint.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(conversation.title)
                        .font(AppFont.callout())
                        .foregroundStyle(AppColor.text)
                        .lineLimit(1)
                    Text(conversation.preview)
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(Spacing.md)
            .background(isSelected ? AppColor.lift : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
