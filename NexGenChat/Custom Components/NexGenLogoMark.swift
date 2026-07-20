import SwiftUI

/// Brand logo mark — the NexGen hexagon-web glyph rendered from the app asset.
struct NexGenLogoMark: View {
    var size: CGFloat = 64

    var body: some View {
        Image("NexGenLogo")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: AppColor.accent.opacity(0.35), radius: size * 0.18, y: size * 0.06)
    }
}

#Preview {
    ZStack {
        AppColor.background.ignoresSafeArea()
        NexGenLogoMark(size: 96)
    }
}
