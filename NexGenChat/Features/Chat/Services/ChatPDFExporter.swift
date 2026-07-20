import UIKit

/// Renders a conversation transcript to a PDF file, mirroring the web app's
/// `downloadChatPDF`. Returns a temp-file URL suitable for a share sheet.
enum ChatPDFExporter {

    static func export(_ conversation: Conversation) -> URL? {
        let html = buildHTML(conversation)
        let formatter = UIMarkupTextPrintFormatter(markupText: html)

        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)

        // US Letter with a margin.
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let printable = page.insetBy(dx: 28, dy: 36)
        renderer.setValue(page, forKey: "paperRect")
        renderer.setValue(printable, forKey: "printableRect")

        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, page, nil)
        renderer.prepare(forDrawingPages: NSRange(location: 0, length: renderer.numberOfPages))
        let bounds = UIGraphicsGetPDFContextBounds()
        for i in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: bounds)
        }
        UIGraphicsEndPDFContext()

        let name = sanitizedFileName(conversation.title)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name).pdf")
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
                <div style="margin:0 0 18px 0">
                  <div style="font:600 11px -apple-system;color:\(color);letter-spacing:1px;text-transform:uppercase;margin-bottom:4px">\(who)</div>
                  <div style="font:14px/1.55 -apple-system;color:#111;white-space:pre-wrap">\(escape(message.text))</div>
                </div>
                """
            }
            .joined()

        return """
        <html><body style="margin:0;padding:0">
          <h1 style="font:700 20px -apple-system;color:#0F2645;margin:0 0 4px 0">\(escape(conversation.title))</h1>
          <div style="font:11px -apple-system;color:#888;margin:0 0 20px 0">NexGen Chat · \(formattedDate(conversation.updatedAt))</div>
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
