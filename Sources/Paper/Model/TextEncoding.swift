import Foundation

/// A selectable text encoding, wrapping `String.Encoding` with a stable id and label.
struct TextEncoding: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let encoding: String.Encoding

    init(id: String, displayName: String, encoding: String.Encoding) {
        self.id = id
        self.displayName = displayName
        self.encoding = encoding
    }

    /// Compact label for the status bar (e.g. "EUC-KR" from "EUC-KR (한국어)").
    var shortName: String {
        displayName.components(separatedBy: " ").first ?? displayName
    }

    // MARK: Presets

    static let utf8      = TextEncoding(id: "utf8",      displayName: "UTF-8",              encoding: .utf8)
    static let utf8BOM   = TextEncoding(id: "utf8bom",   displayName: "UTF-8 (BOM)",        encoding: .utf8)
    static let utf16LE   = TextEncoding(id: "utf16le",   displayName: "UTF-16 LE",          encoding: .utf16LittleEndian)
    static let utf16BE   = TextEncoding(id: "utf16be",   displayName: "UTF-16 BE",          encoding: .utf16BigEndian)
    static let eucKR     = TextEncoding(id: "euckr",     displayName: "EUC-KR (한국어)",     encoding: .eucKR)
    static let shiftJIS  = TextEncoding(id: "shiftjis",  displayName: "Shift-JIS (일본어)",  encoding: .shiftJIS)
    static let gb18030   = TextEncoding(id: "gb18030",   displayName: "GB18030 (중국어)",    encoding: .gb18030)
    static let latin1    = TextEncoding(id: "latin1",    displayName: "ISO Latin-1",        encoding: .isoLatin1)
    static let macRoman  = TextEncoding(id: "macroman",  displayName: "Mac OS Roman",       encoding: .macOSRoman)
    static let ascii     = TextEncoding(id: "ascii",     displayName: "ASCII",              encoding: .ascii)

    /// The encodings offered in settings, in menu order.
    static let all: [TextEncoding] = [
        .utf8, .utf8BOM, .utf16LE, .utf16BE, .eucKR, .shiftJIS, .gb18030, .latin1, .macRoman, .ascii
    ]

    static func byID(_ id: String) -> TextEncoding {
        all.first { $0.id == id } ?? .utf8
    }
}

extension String.Encoding {
    /// EUC-KR / Windows-949 — not exposed directly by `String.Encoding`.
    static let eucKR = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.EUC_KR.rawValue))
    )
    static let gb18030 = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
    )
    static let shiftJIS = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.dosJapanese.rawValue))
    )
}

/// Result of loading a file: the decoded string plus the detected encoding and line ending.
struct DecodedFile {
    var text: String
    var encoding: TextEncoding
    var lineEnding: LineEnding
}

enum FileCodec {
    /// Decodes raw file data, auto-detecting the encoding. `preferred` is tried first.
    static func decode(_ data: Data, preferred: TextEncoding) -> DecodedFile {
        // 1) BOM sniffing.
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            let body = data.dropFirst(3)
            if let s = String(data: body, encoding: .utf8) {
                return DecodedFile(text: s, encoding: .utf8BOM, lineEnding: LineEnding.detect(in: s))
            }
        }
        if data.starts(with: [0xFF, 0xFE]) {
            if let s = String(data: data.dropFirst(2), encoding: .utf16LittleEndian) {
                return DecodedFile(text: s, encoding: .utf16LE, lineEnding: LineEnding.detect(in: s))
            }
        }
        if data.starts(with: [0xFE, 0xFF]) {
            if let s = String(data: data.dropFirst(2), encoding: .utf16BigEndian) {
                return DecodedFile(text: s, encoding: .utf16BE, lineEnding: LineEnding.detect(in: s))
            }
        }

        // 2) Try the preferred encoding, then strict UTF-8, then common fallbacks.
        var order: [TextEncoding] = [preferred, .utf8, .eucKR, .shiftJIS, .gb18030]
        // De-duplicate while preserving order.
        var seen = Set<String>()
        order = order.filter { seen.insert($0.id).inserted }

        for enc in order {
            if let s = String(data: data, encoding: enc.encoding) {
                return DecodedFile(text: s, encoding: enc, lineEnding: LineEnding.detect(in: s))
            }
        }

        // 3) Last resort: Latin-1 maps every byte, so it never fails.
        let s = String(data: data, encoding: .isoLatin1) ?? ""
        return DecodedFile(text: s, encoding: .latin1, lineEnding: LineEnding.detect(in: s))
    }

    /// Encodes `text` for writing, applying `lineEnding` and prepending a BOM when required.
    static func encode(_ text: String, encoding: TextEncoding, lineEnding: LineEnding) -> Data? {
        let normalized = lineEnding.normalize(text)
        guard var data = normalized.data(using: encoding.encoding, allowLossyConversion: false) else {
            return nil
        }
        if encoding.id == "utf8bom" {
            data.insert(contentsOf: [0xEF, 0xBB, 0xBF], at: 0)
        }
        return data
    }
}
