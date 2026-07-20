import SwiftUI

/// Styled text field with an SF Symbol leading icon and validation state.
struct CustomTextField: View {
    let title: String
    let systemImage: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .never
    var showError: Bool = false

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: systemImage)
                .foregroundStyle(focused ? AppColor.accent : AppColor.muted)
                .frame(width: 20)

            TextField("", text: $text, prompt: Text(title).foregroundColor(AppColor.muted))
                .font(AppFont.body())
                .foregroundStyle(AppColor.text)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled()
                .focused($focused)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md + 2)
        .background(AppColor.panel)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.15), value: focused)
    }

    private var borderColor: Color {
        if showError { return AppColor.danger }
        return focused ? AppColor.accent : AppColor.lift
    }
}
