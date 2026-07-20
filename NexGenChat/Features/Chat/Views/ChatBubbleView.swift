import SwiftUI

/// One message row: user (right, accent), assistant (left, surface),
/// or an inline error banner.
struct ChatBubbleView: View {
    let message: ChatMessage
    let modelTint: Color

    var body: some View {
        switch message.role {
        case .user:      userBubble
        case .assistant: assistantBubble
        case .error:     errorBubble
        case .system:    EmptyView()
        }
    }

    // MARK: - Variants

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 48)
            VStack(alignment: .trailing, spacing: Spacing.xs) {
                if let image = attachedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 220, maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                }
                Text(Self.markdown(message.text))
                    .font(AppFont.body())
                    .foregroundStyle(.white)
                    .tint(.white)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(AppColor.accentGradient)
            .clipShape(BubbleShape(isUser: true))
        }
    }

    private var attachedImage: UIImage? {
        guard let b64 = message.imageBase64, let data = Data(base64Encoded: b64) else { return nil }
        return UIImage(data: data)
    }

    private var assistantBubble: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            avatar
            VStack(alignment: .leading, spacing: Spacing.xs) {
                if message.text.isEmpty && message.isStreaming {
                    TypingIndicator(tint: modelTint)
                } else {
                    Text(Self.markdown(message.text))
                        .font(AppFont.body())
                        .foregroundStyle(AppColor.text)
                        .tint(AppColor.accent)
                        .textSelection(.enabled)
                    if message.isStreaming {
                        TypingIndicator(tint: modelTint)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(AppColor.surface)
            .clipShape(BubbleShape(isUser: false))
            Spacer(minLength: 24)
        }
    }

    private var errorBubble: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message.text)
                .font(AppFont.caption())
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(AppColor.danger)
        .padding(Spacing.md)
        .background(AppColor.danger.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
    }

    /// Render inline markdown (bold/italic/links/inline code), preserving line
    /// breaks. Falls back to plain text if parsing fails or while streaming
    /// partial syntax.
    private static func markdown(_ raw: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: raw, options: options))
            ?? AttributedString(raw)
    }

    private var avatar: some View {
        Circle()
            .fill(modelTint.opacity(0.18))
            .frame(width: 30, height: 30)
            .overlay(
                Image(systemName: "sparkle")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(modelTint)
            )
    }
}

/// Asymmetric rounded bubble (tighter corner on the sender's side).
private struct BubbleShape: Shape {
    let isUser: Bool
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = Radius.lg
        let corners: UIRectCorner = isUser
            ? [.topLeft, .topRight, .bottomLeft]
            : [.topLeft, .topRight, .bottomRight]
        return Path(UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: r, height: r)
        ).cgPath)
    }
}

/// Three-dot animated "assistant is typing" indicator.
struct TypingIndicator: View {
    let tint: Color
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
                    .opacity(phase == i ? 1 : 0.3)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever()) { }
            Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
                phase = (phase + 1) % 3
            }
        }
    }
}

#Preview {
    ZStack {
        AppColor.background.ignoresSafeArea()
        VStack(spacing: 12) {
            ChatBubbleView(message: .init(role: .user, text: "How does Ultra differ from Pro?"), modelTint: AppColor.pro)
            ChatBubbleView(message: .init(role: .assistant, text: "Ultra is tuned for deep reasoning and longer context.", isStreaming: true), modelTint: AppColor.ultra)
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
