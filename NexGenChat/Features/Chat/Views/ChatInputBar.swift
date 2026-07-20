import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Bottom composer: auto-growing text field, image-attach button, and a
/// send/stop button that swaps while the assistant is streaming.
struct ChatInputBar: View {
    @Binding var text: String
    let isStreaming: Bool
    let canSend: Bool
    let onSend: () -> Void
    let onStop: () -> Void
    var placeholder: String = "Message NexGen Chat…"
    var pendingImage: UIImage? = nil
    var onImagePicked: (Data) -> Void = { _ in }
    var onRemoveImage: () -> Void = {}
    var pendingDocName: String? = nil
    var onDocPicked: (URL) -> Void = { _ in }
    var onRemoveDoc: () -> Void = {}

    @FocusState private var focused: Bool
    @State private var pickerItem: PhotosPickerItem?
    @State private var showDocImporter = false

    var body: some View {
        VStack(spacing: Spacing.sm) {
            if let image = pendingImage {
                imagePreview(image)
            }
            if let docName = pendingDocName {
                docChip(docName)
            }
            composer
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(.ultraThinMaterial)
        .animation(.easeInOut(duration: 0.15), value: isStreaming)
        .animation(.easeInOut(duration: 0.15), value: pendingImage != nil)
        .animation(.easeInOut(duration: 0.15), value: pendingDocName)
        .fileImporter(isPresented: $showDocImporter,
                      allowedContentTypes: [.pdf, .plainText, .text],
                      allowsMultipleSelection: false) { result in
            if case let .success(urls) = result, let url = urls.first {
                onDocPicked(url)
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(AppColor.muted)
            }
            .padding(.bottom, 4)
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        onImagePicked(data)
                    }
                    pickerItem = nil
                }
            }

            Button { showDocImporter = true } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppColor.muted)
            }
            .padding(.bottom, 6)

            TextField(placeholder, text: $text, axis: .vertical)
                .font(AppFont.body())
                .foregroundStyle(AppColor.text)
                .tint(AppColor.accent)
                .lineLimit(1...6)
                .focused($focused)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm + 2)
                .background(AppColor.panel)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(focused ? AppColor.lift : .clear, lineWidth: 1)
                )

            sendButton
        }
    }

    private func imagePreview(_ image: UIImage) -> some View {
        HStack {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                Button(action: onRemoveImage) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white, AppColor.danger)
                }
                .offset(x: 6, y: -6)
            }
            Spacer()
        }
    }

    private func docChip(_ name: String) -> some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 12))
                Text(name)
                    .font(AppFont.caption())
                    .lineLimit(1)
                Button(action: onRemoveDoc) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                }
            }
            .foregroundStyle(AppColor.dim)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 6)
            .background(AppColor.panel)
            .clipShape(Capsule())
            Spacer()
        }
    }

    private var sendButton: some View {
        Button {
            isStreaming ? onStop() : onSend()
        } label: {
            Image(systemName: isStreaming ? "stop.fill" : "arrow.up")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(
                        isStreaming ? AnyShapeStyle(AppColor.danger)
                                    : AnyShapeStyle(AppColor.accentGradient)
                    )
                )
                .opacity(isStreaming || canSend ? 1 : 0.4)
        }
        .disabled(!isStreaming && !canSend)
        .padding(.bottom, 2)
    }
}

#Preview {
    ZStack {
        AppColor.background.ignoresSafeArea()
        VStack {
            Spacer()
            ChatInputBar(text: .constant(""), isStreaming: false, canSend: false, onSend: {}, onStop: {})
        }
    }
    .preferredColorScheme(.dark)
}
