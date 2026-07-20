import Foundation

/// Renders a conversation into a PowerPoint (`.pptx`) deck, mirroring the web
/// app's `downloadLastPptx`. Builds a minimal-but-valid OOXML package (one title
/// slide plus one slide per message) and zips it with `ZipArchive`. Opens in
/// PowerPoint, Keynote, and Quick Look. Returns a temp-file URL for a share sheet.
enum ChatPptxExporter {

    static func export(_ conversation: Conversation) -> URL? {
        var slides: [(title: String, body: String)] = []
        slides.append((conversation.title, "NexGen Chat · \(formattedDate(conversation.updatedAt))"))
        for message in conversation.messages where message.role == .user || message.role == .assistant {
            let who = message.role == .user ? "You" : "NexGen \(conversation.model.displayName)"
            slides.append((who, message.text))
        }

        var zip = ZipArchive()
        zip.addFile(path: "[Content_Types].xml", string: contentTypes(slideCount: slides.count))
        zip.addFile(path: "_rels/.rels", string: rootRels)
        zip.addFile(path: "ppt/presentation.xml", string: presentation(slideCount: slides.count))
        zip.addFile(path: "ppt/_rels/presentation.xml.rels", string: presentationRels(slideCount: slides.count))
        zip.addFile(path: "ppt/theme/theme1.xml", string: theme)
        zip.addFile(path: "ppt/slideMasters/slideMaster1.xml", string: slideMaster)
        zip.addFile(path: "ppt/slideMasters/_rels/slideMaster1.xml.rels", string: slideMasterRels)
        zip.addFile(path: "ppt/slideLayouts/slideLayout1.xml", string: slideLayout)
        zip.addFile(path: "ppt/slideLayouts/_rels/slideLayout1.xml.rels", string: slideLayoutRels)
        for (index, slide) in slides.enumerated() {
            let n = index + 1
            zip.addFile(path: "ppt/slides/slide\(n).xml", string: slideXML(title: slide.title, body: slide.body))
            zip.addFile(path: "ppt/slides/_rels/slide\(n).xml.rels", string: slideRels)
        }

        let name = sanitizedFileName(conversation.title)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name).pptx")
        do {
            try zip.data().write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Package parts

    private static func contentTypes(slideCount: Int) -> String {
        let slideOverrides = (1...slideCount).map {
            "<Override PartName=\"/ppt/slides/slide\($0).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>"
        }.joined()
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\
        <Default Extension="xml" ContentType="application/xml"/>\
        <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>\
        <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>\
        <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>\
        <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>\
        \(slideOverrides)</Types>
        """
    }

    private static let rootRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>\
    </Relationships>
    """

    private static func presentation(slideCount: Int) -> String {
        let sldIds = (1...slideCount).map {
            "<p:sldId id=\"\(255 + $0)\" r:id=\"rIdS\($0)\"/>"
        }.joined()
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">\
        <p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rIdM"/></p:sldMasterIdLst>\
        <p:sldIdLst>\(sldIds)</p:sldIdLst>\
        <p:sldSz cx="12192000" cy="6858000" type="screen16x9"/>\
        <p:notesSz cx="6858000" cy="9144000"/>\
        </p:presentation>
        """
    }

    private static func presentationRels(slideCount: Int) -> String {
        let slideRelsList = (1...slideCount).map {
            "<Relationship Id=\"rIdS\($0)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide\($0).xml\"/>"
        }.joined()
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
        <Relationship Id="rIdM" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>\
        <Relationship Id="rIdT" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>\
        \(slideRelsList)</Relationships>
        """
    }

    private static func slideXML(title: String, body: String) -> String {
        let bodyParagraphs = body
            .components(separatedBy: "\n")
            .map { "<a:p><a:r><a:rPr lang=\"en-US\" sz=\"1800\"/><a:t>\(escape($0))</a:t></a:r></a:p>" }
            .joined()
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">\
        <p:cSld><p:spTree>\
        <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>\
        <p:sp>\
        <p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>\
        <p:spPr><a:xfrm><a:off x="457200" y="274638"/><a:ext cx="11277600" cy="1000000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>\
        <p:txBody><a:bodyPr wrap="square"/><a:lstStyle/><a:p><a:r><a:rPr lang="en-US" sz="3200" b="1"/><a:t>\(escape(title))</a:t></a:r></a:p></p:txBody>\
        </p:sp>\
        <p:sp>\
        <p:nvSpPr><p:cNvPr id="3" name="Body"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>\
        <p:spPr><a:xfrm><a:off x="457200" y="1400000"/><a:ext cx="11277600" cy="5200000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>\
        <p:txBody><a:bodyPr wrap="square"><a:normAutofit/></a:bodyPr><a:lstStyle/>\(bodyParagraphs)</p:txBody>\
        </p:sp>\
        </p:spTree></p:cSld>\
        </p:sld>
        """
    }

    private static let slideRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>\
    </Relationships>
    """

    private static let slideMaster = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">\
    <p:cSld><p:spTree>\
    <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>\
    </p:spTree></p:cSld>\
    <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>\
    <p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>\
    </p:sldMaster>
    """

    private static let slideMasterRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>\
    <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>\
    </Relationships>
    """

    private static let slideLayout = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank" preserve="1">\
    <p:cSld name="Blank"><p:spTree>\
    <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>\
    </p:spTree></p:cSld>\
    <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>\
    </p:sldLayout>
    """

    private static let slideLayoutRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>\
    </Relationships>
    """

    private static let theme = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="NexGen">\
    <a:themeElements>\
    <a:clrScheme name="NexGen">\
    <a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1><a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>\
    <a:dk2><a:srgbClr val="0F2645"/></a:dk2><a:lt2><a:srgbClr val="EEF4F8"/></a:lt2>\
    <a:accent1><a:srgbClr val="0077B6"/></a:accent1><a:accent2><a:srgbClr val="00A0C8"/></a:accent2>\
    <a:accent3><a:srgbClr val="48CAE4"/></a:accent3><a:accent4><a:srgbClr val="90E0EF"/></a:accent4>\
    <a:accent5><a:srgbClr val="0096C7"/></a:accent5><a:accent6><a:srgbClr val="023E8A"/></a:accent6>\
    <a:hlink><a:srgbClr val="0077B6"/></a:hlink><a:folHlink><a:srgbClr val="023E8A"/></a:folHlink>\
    </a:clrScheme>\
    <a:fontScheme name="NexGen">\
    <a:majorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>\
    <a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>\
    </a:fontScheme>\
    <a:fmtScheme name="NexGen">\
    <a:fillStyleLst>\
    <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>\
    <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>\
    <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>\
    </a:fillStyleLst>\
    <a:lnStyleLst>\
    <a:ln w="6350"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>\
    <a:ln w="12700"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>\
    <a:ln w="19050"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>\
    </a:lnStyleLst>\
    <a:effectStyleLst>\
    <a:effectStyle><a:effectLst/></a:effectStyle>\
    <a:effectStyle><a:effectLst/></a:effectStyle>\
    <a:effectStyle><a:effectLst/></a:effectStyle>\
    </a:effectStyleLst>\
    <a:bgFillStyleLst>\
    <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>\
    <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>\
    <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>\
    </a:bgFillStyleLst>\
    </a:fmtScheme>\
    </a:themeElements>\
    </a:theme>
    """

    // MARK: - Helpers

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
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
