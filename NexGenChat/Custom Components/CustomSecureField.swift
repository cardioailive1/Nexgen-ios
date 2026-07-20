import SwiftUI

/// Secure entry field with a show/hide toggle, matching `CustomTextField`.
struct CustomSecureField: View {
    let title: String
    @Binding var text: String
    var contentType: UITextContentType? = .password
    var showError: Bool = false

    @State private var isRevealed = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "lock.fill")
                .foregroundStyle(focused ? AppColor.accent : AppColor.muted)
                .frame(width: 20)

            Group {
                if isRevealed {
                    TextField("", text: $text, prompt: prompt)
                } else {
                    SecureField("", text: $text, prompt: prompt)
                }
            }
            .font(AppFont.body())
            .foregroundStyle(AppColor.text)
            .textContentType(contentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focused)

            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                    .foregroundStyle(AppColor.muted)
            }
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

    private var prompt: Text {
        Text(title).foregroundColor(AppColor.muted)
    }

    private var borderColor: Color {
        if showError { return AppColor.danger }
        return focused ? AppColor.accent : AppColor.lift
    }
}
