import Foundation
import Observation

/// One open document (a tab). Metadata and cursor stats are observed so the UI
/// (tab title, status bar) updates reactively; the text body itself is kept out
/// of observation — the `NSTextView` is the live source of truth while editing,
/// and `text` is synced on load, tab-switch, and save.
@Observable
final class TextDocument: Identifiable {
    let id = UUID()

    /// On-disk location, or nil for an unsaved document.
    var url: URL?

    /// Cached content. Not observed: edits flow through the AppKit text view for
    /// performance; this is refreshed when the document loses focus or is saved.
    @ObservationIgnored var text: String

    var encoding: TextEncoding
    var lineEnding: LineEnding

    /// True when the buffer differs from what's on disk.
    var isDirty: Bool = false

    // Cursor / selection stats, pushed from the editor.
    var caretLine: Int = 1
    var caretColumn: Int = 1
    var selectedCount: Int = 0
    var characterCount: Int = 0

    /// Monotonic id for untitled documents ("제목 없음", "제목 없음 2", …).
    let untitledNumber: Int

    init(url: URL? = nil,
         text: String = "",
         encoding: TextEncoding = .utf8,
         lineEnding: LineEnding = .lf,
         untitledNumber: Int = 1) {
        self.url = url
        self.text = text
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.characterCount = text.count
        self.untitledNumber = untitledNumber
    }

    /// Tab/window title.
    var displayName: String {
        if let url { return url.lastPathComponent }
        return untitledNumber <= 1 ? "제목 없음" : "제목 없음 \(untitledNumber)"
    }

    /// Parent directory shown in quick-open, abbreviated with "~".
    var directoryDisplay: String {
        guard let url else { return "저장 안 됨" }
        let dir = url.deletingLastPathComponent().path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if dir.hasPrefix(home) {
            return "~" + dir.dropFirst(home.count)
        }
        return dir
    }

    var isUntitled: Bool { url == nil }
}

extension TextDocument: Hashable {
    static func == (lhs: TextDocument, rhs: TextDocument) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
