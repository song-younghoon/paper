import Foundation

/// An entry in the sidebar "최근 항목" list and the ⌘P quick-open list.
struct RecentFile: Identifiable, Hashable {
    let url: URL
    var id: String { url.path }
    var name: String { url.lastPathComponent }
    var directoryDisplay: String { url.abbreviatedDirectory }
}

/// A folder shortcut in the sidebar "폴더" section.
struct SidebarFolder: Identifiable, Hashable {
    let url: URL
    var count: Int
    var id: String { url.path }
    var name: String { url.lastPathComponent }
}

/// An item inside a folder — either a subfolder or a text file.
struct FolderEntry: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool
    var id: String { url.path }
    var name: String { url.lastPathComponent }
}
