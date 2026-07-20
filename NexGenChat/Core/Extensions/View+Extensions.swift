import SwiftUI

extension View {
    /// Standard "lifted panel" card surface used throughout the app.
    func cardSurface(padding: CGFloat = Spacing.lg,
                     radius: CGFloat = Radius.lg) -> some View {
        self
            .padding(padding)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(AppColor.lift, lineWidth: 1)
            )
    }

    /// Dismiss the keyboard from anywhere.
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
    }

    /// Conditionally apply a modifier.
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool,
                             transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}
