import SwiftUI

struct QuickOpenItem: Identifiable {
    let url: URL
    let isOpen: Bool
    var id: String { url.path }
    var name: String { url.lastPathComponent }
    var directory: String { url.abbreviatedDirectory }
}

/// The ⌘P quick-open palette (design 1e): fuzzy file-name search over open tabs,
/// recent files, and folder shortcuts.
struct QuickOpenView: View {
    @Environment(AppState.self) private var app
    @Environment(\.paperTheme) private var theme
    @Environment(\.renderMock) private var renderMock

    @State private var query = ""
    @State private var selection = 0
    @FocusState private var focused: Bool

    private var candidates: [QuickOpenItem] {
        var seen = Set<String>()
        var items: [QuickOpenItem] = []
        func add(_ url: URL, open: Bool) {
            guard seen.insert(url.path).inserted else { return }
            items.append(QuickOpenItem(url: url, isOpen: open))
        }
        for d in app.documents where d.url != nil { add(d.url!, open: true) }
        for r in app.recentFiles { add(r.url, open: false) }
        for folder in app.folders {
            for f in app.textFiles(in: folder) { add(f.url, open: false) }
        }
        return items
    }

    private var results: [QuickOpenItem] {
        guard !query.isEmpty else { return candidates }
        return candidates
            .compactMap { item -> (QuickOpenItem, Int)? in
                guard let score = fuzzyScore(query, item.name) else { return nil }
                return (item, score)
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    var body: some View {
        PaletteScaffold(onBackgroundTap: close) {
            VStack(spacing: 0) {
                header
                Rectangle().fill(theme.divider.color).frame(height: 1)
                list
                Rectangle().fill(theme.divider.color).frame(height: 1)
                PaletteFooter(hints: [("↑↓", "이동"), ("↵", "열기"), ("⌘↵", "새 탭에서 열기")])
            }
        }
        .paletteKeyMonitor(onUp: moveUp, onDown: moveDown, onSelect: { _ in openSelected() }, onClose: close)
        .onAppear { focused = true; selection = 0 }
        .onChange(of: query) { _, _ in selection = 0 }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(theme.tertiaryText.color)
            if renderMock {
                Text(query.isEmpty ? "파일 이름 검색…" : query)
                    .font(.system(size: 15))
                    .foregroundStyle(query.isEmpty ? theme.tertiaryText.color : theme.primaryText.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField("파일 이름 검색…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.primaryText.color)
                    .focused($focused)
            }
            Text("⌘P")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.tertiaryText.color)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(theme.primaryText.color.opacity(0.07)))
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
    }

    private var list: some View {
        Group {
            if renderMock {
                VStack(spacing: 2) { rows(Array(results.prefix(9).enumerated())) }
                    .padding(8)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) { rows(Array(results.enumerated())) }
                            .padding(8)
                    }
                    .frame(maxHeight: 360)
                    .onChange(of: selection) { _, new in
                        withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(new, anchor: .center) }
                    }
                }
            }
        }
    }

    @ViewBuilder private func rows(_ items: [(offset: Int, element: QuickOpenItem)]) -> some View {
        if !items.isEmpty && query.isEmpty {
            Text("최근 파일")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.tertiaryText.color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12).padding(.top, 6).padding(.bottom, 2)
        }
        ForEach(items, id: \.element.id) { index, item in
            QuickOpenRow(item: item, selected: index == selection)
                .id(index)
                .onTapGesture { selection = index; openSelected() }
                .onHover { if $0 { selection = index } }
        }
        if items.isEmpty {
            Text(candidates.isEmpty ? "최근 파일이 없습니다" : "일치하는 파일이 없습니다")
                .font(.system(size: 13))
                .foregroundStyle(theme.tertiaryText.color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        }
    }

    private func moveUp() { if !results.isEmpty { selection = (selection - 1 + results.count) % results.count } }
    private func moveDown() { if !results.isEmpty { selection = (selection + 1) % results.count } }
    private func openSelected() {
        guard results.indices.contains(selection) else { return }
        let url = results[selection].url
        close()
        DispatchQueue.main.async { app.open(url: url) }
    }
    private func close() { app.quickOpenVisible = false }
}

private struct QuickOpenRow: View {
    let item: QuickOpenItem
    let selected: Bool
    @Environment(\.paperTheme) private var theme

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "doc.text")
                .font(.system(size: 13))
                .foregroundStyle(selected ? theme.onAccent.color : theme.secondaryText.color)
                .frame(width: 20)
            Text(item.name)
                .font(.system(size: 13.5))
                .foregroundStyle(selected ? theme.onAccent.color : theme.primaryText.color)
                .lineLimit(1)
            if item.isOpen {
                Text("열림")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(selected ? theme.onAccent.color.opacity(0.85) : theme.tertiaryText.color)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 4).fill((selected ? theme.onAccent.color : theme.secondaryText.color).opacity(0.15)))
            }
            Spacer(minLength: 8)
            Text(item.directory)
                .font(.system(size: 11.5))
                .foregroundStyle(selected ? theme.onAccent.color.opacity(0.85) : theme.tertiaryText.color)
                .lineLimit(1)
                .truncationMode(.head)
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selected ? theme.accent.color : Color.clear)
        )
        .contentShape(Rectangle())
    }
}
