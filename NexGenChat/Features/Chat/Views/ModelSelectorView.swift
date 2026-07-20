import SwiftUI

/// Flash / Pro / Ultra segmented model picker.
struct ModelSelectorView: View {
    let selected: AIModel
    var lockedModels: Set<AIModel> = []
    let onSelect: (AIModel) -> Void
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AIModel.allCases) { model in
                let isSelected = model == selected
                let isLocked = lockedModels.contains(model)
                Button {
                    onSelect(model)
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: isLocked ? "lock.fill" : model.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(model.displayName)
                            .font(AppFont.caption())
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(isSelected ? .white : (isLocked ? AppColor.muted.opacity(0.6) : AppColor.muted))
                    .padding(.vertical, Spacing.sm)
                    .frame(maxWidth: .infinity)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .fill(model.tint)
                                .matchedGeometryEffect(id: "modelPill", in: pill)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(AppColor.panel)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .animation(.easeInOut(duration: 0.22), value: selected)
    }
}

#Preview {
    ZStack {
        AppColor.background.ignoresSafeArea()
        ModelSelectorView(selected: .pro, onSelect: { _ in })
            .padding()
    }
    .preferredColorScheme(.dark)
}
