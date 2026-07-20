import Foundation

/// Renders a conversation transcript to a Word-openable document, mirroring the
/// web app's `downloadChatWord`. iOS has no native OOXML (`.docx`) writer and no
/// bundled zip library, so we emit Word-flavored HTML with the Office XML
/// namespaces and a `.doc` extension — Word, Pages, and Quick Look all open it.
/// Returns a temp-file URL suitable for a share sheet.
enum ChatDocExporter {

    static func export(_ conversation: Conversation) -> URL? {
        let html = buildHTML(conversation)
        guard let data = html.data(using: .utf8) else { return nil }

        let name = sanitizedFileName(conversation.title)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name).doc")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - HTML

    private static func buildHTML(_ conversation: Conversation) -> String {
        let rows = conversation.messages
            .filter { $0.role == .user || $0.role == .assistant }
            .map { message -> String in
                let who = message.role == .user ? "You" : "NexGen \(conversation.model.displayName)"
                let color = message.role == .user ? "#0077B6" : "#00A0C8"
                return """
                <p style="font:600 11px Arial;color:\(color);text-transform:uppercase;margin:0 0 4px 0">\(escape(who))</p>
                <p style="font:11pt/1.5 Calibri,Arial;color:#111;margin:0 0 18px 0;white-space:pre-wrap">\(escape(message.text))</p>
                """
            }
            .joined()

        // The Office namespaces on <html> are what makes Word treat this as a
        // document rather than a web page.
        return """
        <html xmlns:o="urn:schemas-microsoft-com:office:office" \
        xmlns:w="urn:schemas-microsoft-com:office:word" \
        xmlns="http://www.w3.org/TR/REC-html40">
        <head><meta charset="utf-8"><title>\(escape(conversation.title))</title></head>
        <body>
          <h1 style="font:700 18pt Calibri,Arial;color:#0F2645;margin:0 0 4px 0">\(escape(conversation.title))</h1>
          <p style="font:9pt Arial;color:#888;margin:0 0 20px 0">NexGen Chat · \(formattedDate(conversation.updatedAt))</p>
          \(rows)
        </body></html>
        """
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func sanitizedFileName(_ title: String) -> String {
        let base = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = base.isEmpty ? "NexGen Chat" : base
        return cleaned.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>"))
            .joined(separator: "-")
    }

    private static func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
