import SwiftUI

/// The left sidebar: search field, "최근 항목" (recent files, removable), and "폴더"
/// (folder shortcuts that expand recursively into subfolders and files).
struct SidebarView: View {
    @Environment(AppState.self) private var app
    @Environment(\.paperTheme) private var theme
    @Environment(\.renderMock) private var renderMock

    private var query: String {
        app.sidebarSearch.trimmingCharacters(in: .whitespaces)
    }

    private var filteredRecents: [RecentFile] {
        guard !query.isEmpty else { return app.recentFiles }
        return app.recentFiles.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        @Bindable var app = app
        VStack(spacing: 0) {
            searchField
            if renderMock {
                content.frame(maxWidth: .infinity, alignment: .topLeading)
                Spacer(minLength: 0)
            } else {
                ScrollView { content }
            }
        }
        .frame(maxHeight: .infinity)
        .background(theme.sidebarBackground.color)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 1) {
            recentSection
            folderSection
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 12)
    }

    // MARK: Search

    private var searchField: some View {
        @Bindable var app = app
        return HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(theme.tertiaryText.color)
            if renderMock {
                Text(app.sidebarSearch.isEmpty ? "검색" : app.sidebarSearch)
                    .font(.system(size: 12.5))
                    .foregroundStyle(app.sidebarSearch.isEmpty ? theme.tertiaryText.color : theme.primaryText.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField("검색", text: $app.sidebarSearch)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(theme.primaryText.color)
            }
            if !app.sidebarSearch.isEmpty {
                Button { app.sidebarSearch = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.tertiaryText.color)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(theme.controlBackground.color))
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // MARK: Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 1) {
            sectionHeader("최근 항목", actionIcon: app.recentFiles.isEmpty ? nil : "xmark.circle",
                          actionHelp: "최근 항목 모두 지우기") { app.clearRecents() }
            if filteredRecents.isEmpty {
                emptyRow(query.isEmpty ? "최근 항목이 없습니다" : "일치하는 항목 없음")
            } else {
                ForEach(filteredRecents) { file in
                    SidebarRow(
                        icon: "doc.text",
                        title: file.name,
                        selected: app.activeDocument?.url == file.url,
                        action: { app.open(url: file.url) },
                        hoverRemove: { app.removeRecent(file.url) },
                        contextRemove: (title: "최근 항목에서 제거", action: { app.removeRecent(file.url) })
                    )
                }
            }
        }
    }

    // MARK: Folders

    private var folderSection: some View {
        VStack(alignment: .leading, spacing: 1) {
            sectionHeader("폴더", actionIcon: "plus", actionHelp: "폴더 추가") { app.addFolderPanel() }
            if app.folders.isEmpty {
                Button { app.addFolderPanel() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.badge.plus").font(.system(size: 12))
                        Text("폴더 추가").font(.system(size: 12.5))
                    }
                    .foregroundStyle(theme.tertiaryText.color)
                    .padding(.horizontal, 8).frame(height: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                ForEach(app.folders) { folder in
                    FolderNode(url: folder.url, count: folder.count, depth: 0, isRoot: true, query: query)
                }
            }
        }
    }

    // MARK: Bits

    private func sectionHeader(_ title: String, actionIcon: String? = nil, actionHelp: String = "",
                               action: (() -> Void)? = nil) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.tertiaryText.color)
            Spacer()
            if let actionIcon, let action {
                Button(action: action) {
                    Image(systemName: actionIcon).font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.tertiaryText.color)
                }
                .buttonStyle(.plain)
                .help(actionHelp)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(theme.tertiaryText.color)
            .padding(.horizontal, 8)
            .frame(height: 26, alignment: .leading)
    }
}

/// A folder in the sidebar that expands to reveal its subfolders (recursively)
/// and text files.
struct FolderNode: View {
    let url: URL
    var count: Int? = nil
    let depth: Int
    let isRoot: Bool
    let query: String

    @Environment(AppState.self) private var app
    @Environment(\.renderMock) private var renderMock

    private var isOpen: Bool { app.isFolderExpanded(url.path) }

    private var entries: [FolderEntry] {
        guard isOpen, !renderMock else { return [] }
        let all = app.entries(in: url)
        guard !query.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            SidebarRow(
                icon: isOpen ? "folder.fill" : "folder",
                title: url.lastPathComponent,
                trailing: count.map { "\($0)" },
                indent: CGFloat(depth) * 14,
                chevron: isOpen ? .down : .right,
                action: { app.toggleFolder(url.path) },
                contextRemove: isRoot ? (title: "폴더 제거", action: { app.removeFolder(url: url) }) : nil
            )
            if isOpen {
                ForEach(entries) { entry in
                    if entry.isDirectory {
                        FolderNode(url: entry.url, depth: depth + 1, isRoot: false, query: query)
                    } else {
                        SidebarRow(
                            icon: "doc.text",
                            title: entry.name,
                            selected: app.activeDocument?.url == entry.url,
                            indent: CGFloat(depth + 1) * 14,
                            action: { app.open(url: entry.url) }
                        )
                    }
                }
            }
        }
    }
}

/// One row in the sidebar — a file or a folder — with hover, an optional chevron,
/// an optional hover-revealed remove button, and an optional context-menu remove.
struct SidebarRow: View {
    enum Chevron { case none, right, down }

    let icon: String
    let title: String
    var trailing: String? = nil
    var selected: Bool = false
    var indent: CGFloat = 0
    var chevron: Chevron = .none
    let action: () -> Void
    var hoverRemove: (() -> Void)? = nil
    var contextRemove: (title: String, action: () -> Void)? = nil

    @Environment(\.paperTheme) private var theme
    @State private var hovering = false
    @State private var removeHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if chevron != .none {
                    Image(systemName: chevron == .down ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(theme.tertiaryText.color)
                        .frame(width: 10)
                } else if indent == 0 {
                    Spacer().frame(width: 10)
                }
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(selected ? theme.accent.color : theme.secondaryText.color)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12.5))
                    .foregroundStyle(selected ? theme.primaryText.color : theme.secondaryText.color)
                    .lineLimit(1)
                Spacer(minLength: 4)
                trailingAccessory
            }
            .padding(.leading, 6 + indent)
            .padding(.trailing, 8)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(selected ? theme.sidebarSelection.color
                                   : (hovering ? theme.primaryText.color.opacity(0.04) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .contextMenu {
            if let contextRemove {
                Button(contextRemove.title, role: .destructive, action: contextRemove.action)
            }
        }
    }

    @ViewBuilder private var trailingAccessory: some View {
        if hovering, let hoverRemove {
            Button(action: hoverRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.secondaryText.color)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(theme.primaryText.color.opacity(removeHovering ? 0.14 : 0)))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { removeHovering = $0 }
            .help("최근 항목에서 제거")
        } else if let trailing {
            Text(trailing)
                .font(.system(size: 11))
                .foregroundStyle(theme.tertiaryText.color)
        }
    }
}
