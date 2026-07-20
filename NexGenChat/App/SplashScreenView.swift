import SwiftUI

/// Brief animated launch screen.
struct SplashScreenView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            AppColor.backgroundGradient.ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                NexGenLogoMark(size: 96)
                    .scaleEffect(appeared ? 1 : 0.7)
                    .opacity(appeared ? 1 : 0)

                Text(AppConstants.appName)
                    .font(AppFont.largeTitle())
                    .foregroundStyle(AppColor.text)
                    .opacity(appeared ? 1 : 0)

                Text(AppConstants.company)
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.muted)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
