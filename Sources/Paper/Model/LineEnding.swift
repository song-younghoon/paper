import Foundation

/// The newline convention used by a document.
enum LineEnding: String, CaseIterable, Identifiable, Codable, Sendable {
    case lf    // "\n"     — macOS / Unix
    case crlf  // "\r\n"   — Windows
    case cr    // "\r"     — Classic Mac

    var id: String { rawValue }

    /// The literal characters this line ending inserts.
    var characters: String {
        switch self {
        case .lf:   return "\n"
        case .crlf: return "\r\n"
        case .cr:   return "\r"
        }
    }

    /// Short label for the status bar (e.g. "LF").
    var shortName: String {
        switch self {
        case .lf:   return "LF"
        case .crlf: return "CRLF"
        case .cr:   return "CR"
        }
    }

    /// Descriptive label for settings menus.
    var displayName: String {
        switch self {
        case .lf:   return "LF (macOS·유닉스)"
        case .crlf: return "CRLF (Windows)"
        case .cr:   return "CR (클래식 Mac)"
        }
    }

    /// Detects the predominant line ending in `text`. Defaults to `.lf`.
    static func detect(in text: String) -> LineEnding {
        let ns = text as NSString
        var crlf = 0, lf = 0, cr = 0
        let length = ns.length
        var i = 0
        // Scan a bounded prefix so detection stays fast on huge files.
        let limit = min(length, 200_000)
        while i < limit {
            let c = ns.character(at: i)
            if c == 0x0D { // CR
                if i + 1 < length, ns.character(at: i + 1) == 0x0A {
                    crlf += 1; i += 2; continue
                } else {
                    cr += 1
                }
            } else if c == 0x0A { // LF
                lf += 1
            }
            i += 1
        }
        if crlf >= lf && crlf >= cr && crlf > 0 { return .crlf }
        if cr > lf && cr > 0 { return .cr }
        return .lf
    }

    /// Normalizes any mixture of line endings in `text` to this convention.
    func normalize(_ text: String) -> String {
        // Collapse everything to "\n" first, then expand if needed.
        var normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        normalized = normalized.replacingOccurrences(of: "\r", with: "\n")
        if self == .lf { return normalized }
        return normalized.replacingOccurrences(of: "\n", with: characters)
    }
}
