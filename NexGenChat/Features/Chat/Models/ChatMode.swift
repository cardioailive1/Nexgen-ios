import Foundation

/// Chat modes from the web app (`setMode` / `updateModeSystem`). Each mode swaps
/// the composer placeholder and appends a specialized system prompt. `chat` is
/// the default (no extra prompt).
///
/// `chat`, `graphics`, and `kb` are prompt-only presets (active now). `vision`,
/// `pptx`, and `word` also need attachment / export plumbing and are exposed as
/// those features land.
enum ChatMode: String, CaseIterable, Identifiable {
    case chat, graphics, kb, vision, pptx, word

    var id: String { rawValue }

    /// Modes currently offered in the picker.
    static let available: [ChatMode] = [.chat, .vision, .graphics, .kb]

    var displayName: String {
        switch self {
        case .chat:     return "Chat"
        case .graphics: return "Graphics"
        case .kb:       return "Knowledge Base"
        case .vision:   return "Vision"
        case .pptx:     return "Slides"
        case .word:     return "Document"
        }
    }

    var icon: String {
        switch self {
        case .chat:     return "bubble.left.and.bubble.right.fill"
        case .graphics: return "paintpalette.fill"
        case .kb:       return "books.vertical.fill"
        case .vision:   return "eye.fill"
        case .pptx:     return "rectangle.on.rectangle.angled"
        case .word:     return "doc.text.fill"
        }
    }

    var placeholder: String {
        switch self {
        case .chat:     return "Message NexGen Chat…"
        case .vision:   return "Upload an image above, then ask anything about it…"
        case .graphics: return "Describe what you want to create — SVG, infographic, brand palette…"
        case .pptx:     return "Describe your presentation — topic, audience, number of slides…"
        case .kb:       return "Paste your content or describe what knowledge base to build…"
        case .word:     return "Describe your document — topic, sections, tone…"
        }
    }

    /// The system prompt appended for this mode (empty for `chat`), mirroring the
    /// web app's `_modeSystem`.
    var systemPrompt: String {
        switch self {
        case .chat:
            return ""
        case .vision:
            return "You are a Vision AI specialist. Analyse images with extreme detail and accuracy. Extract text, data, objects, and insights. Always structure your findings clearly with headers and bullet points."
        case .graphics:
            return "You are a professional graphic designer and SVG expert. When creating graphics: always output complete, valid SVG code that renders correctly in browsers. Use professional colour palettes. For design briefs, be specific with hex codes, font names, spacing values and dimensions. When generating SVGs, make them visually polished and production-ready."
        case .kb:
            return "You are a knowledge management specialist. Structure all outputs as well-organised knowledge bases with clear categories, headers, and searchable content. Always include: a master index, categorised sections, and actionable quick-reference cards."
        case .pptx:
            return #"You are a JSON generator. You output nothing but raw JSON. You do not ask questions. You do not explain. You do not greet. You take any presentation request and immediately write all slide content as JSON. Use assumptions where details are missing — never ask for more information. Respond with this exact structure and nothing else: {"title":"Presentation Title","theme":"navy","slides":[{"title":"Slide Title","layout":"title-content","bullets":["First key point","Second key point"],"notes":"Speaker notes"}]}. Include 8-12 slides. Bullet points max 7 words each. Layouts: title-content, two-column, bullets-only, quote, title-only. START YOUR RESPONSE WITH { AND END WITH }. NOTHING ELSE."#
        case .word:
            return #"You are a JSON generator. You output nothing but raw JSON. You do not ask questions. You do not explain. You do not greet. You take any document request and immediately write the full document as JSON. Use assumptions where details are missing — never ask for more information. Respond with this exact structure and nothing else: {"title":"Document Title","subtitle":"Subtitle","author":"Corverxis Technologies","date":"","sections":[{"heading":"Executive Summary","level":1,"content":"Full professional sentences here.","bullets":[]}]}. Write 5-8 sections with real professional content. START YOUR RESPONSE WITH { AND END WITH }. NOTHING ELSE."#
        }
    }
}
