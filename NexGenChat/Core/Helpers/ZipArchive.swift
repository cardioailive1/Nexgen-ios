import Foundation

/// Minimal in-memory ZIP writer using the *store* (no compression) method.
/// iOS ships no public zip container writer, so OOXML packages (`.pptx`,
/// `.docx`, …) are assembled here. Store entries are valid zip and accepted by
/// PowerPoint / Keynote; the parts are small so skipping deflate is fine.
struct ZipArchive {
    private struct Entry {
        let path: String
        let data: Data
    }

    private var entries: [Entry] = []

    /// Add a UTF-8 text part at `path` (e.g. `"ppt/slides/slide1.xml"`).
    mutating func addFile(path: String, string: String) {
        entries.append(Entry(path: path, data: Data(string.utf8)))
    }

    /// Serialize all entries into a single zip archive.
    func data() -> Data {
        var body = Data()
        var central = Data()

        for entry in entries {
            let name = Data(entry.path.utf8)
            let crc = CRC32.checksum(entry.data)
            let size = UInt32(entry.data.count)
            let offset = UInt32(body.count)

            // Local file header.
            body.append(le32(0x04034b50))
            body.append(le16(20))            // version needed
            body.append(le16(0))             // flags
            body.append(le16(0))             // compression: store
            body.append(le16(0))             // mod time
            body.append(le16(0))             // mod date
            body.append(le32(crc))
            body.append(le32(size))          // compressed size
            body.append(le32(size))          // uncompressed size
            body.append(le16(UInt16(name.count)))
            body.append(le16(0))             // extra length
            body.append(name)
            body.append(entry.data)

            // Central directory record.
            central.append(le32(0x02014b50))
            central.append(le16(20))         // version made by
            central.append(le16(20))         // version needed
            central.append(le16(0))          // flags
            central.append(le16(0))          // compression
            central.append(le16(0))          // mod time
            central.append(le16(0))          // mod date
            central.append(le32(crc))
            central.append(le32(size))
            central.append(le32(size))
            central.append(le16(UInt16(name.count)))
            central.append(le16(0))          // extra length
            central.append(le16(0))          // comment length
            central.append(le16(0))          // disk number start
            central.append(le16(0))          // internal attributes
            central.append(le32(0))          // external attributes
            central.append(le32(offset))     // local header offset
            central.append(name)
        }

        let centralOffset = UInt32(body.count)
        let centralSize = UInt32(central.count)
        body.append(central)

        // End of central directory.
        body.append(le32(0x06054b50))
        body.append(le16(0))                 // disk number
        body.append(le16(0))                 // disk with central dir
        body.append(le16(UInt16(entries.count)))
        body.append(le16(UInt16(entries.count)))
        body.append(le32(centralSize))
        body.append(le32(centralOffset))
        body.append(le16(0))                 // comment length
        return body
    }

    // MARK: - Little-endian encoders

    private func le16(_ value: UInt16) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }

    private func le32(_ value: UInt32) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }
}

/// Standard CRC-32 (as required by the zip format).
private enum CRC32 {
    static let table: [UInt32] = (0..<256).map { index -> UInt32 in
        var c = UInt32(index)
        for _ in 0..<8 {
            c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1
        }
        return c
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }
}
