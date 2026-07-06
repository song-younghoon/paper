import Foundation

extension URL {
    /// Directory path with the home folder abbreviated to "~".
    var abbreviatedDirectory: String {
        let dir = deletingLastPathComponent().path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if dir == home { return "~" }
        if dir.hasPrefix(home + "/") { return "~" + dir.dropFirst(home.count) }
        return dir
    }

    /// Heuristic: treat as an editable text file by extension (empty extension allowed).
    var looksLikeTextFile: Bool {
        let ext = pathExtension.lowercased()
        if ext.isEmpty { return true }
        return TextFileTypes.extensions.contains(ext)
    }
}

enum TextFileTypes {
    static let extensions: Set<String> = [
        "txt", "text", "md", "markdown", "log", "csv", "tsv", "json", "xml", "yaml", "yml",
        "html", "htm", "css", "js", "ts", "swift", "c", "h", "cpp", "hpp", "m", "mm",
        "py", "rb", "go", "rs", "java", "kt", "sh", "bash", "zsh", "conf", "ini", "toml",
        "srt", "vtt", "tex", "rtf", "plist", "gitignore", "env", "sql", "r", "lua", "pl"
    ]
}
