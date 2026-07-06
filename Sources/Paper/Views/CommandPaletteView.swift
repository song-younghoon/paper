import SwiftUI

/// One entry in the command palette.
struct PaperCommand: Identifiable {
    let id = UUID()
    let title: String
    var keys: [String] = []
    var icon: String = "command"
    let run: () -> Void
}

/// The ⌘K command palette (design 1d): fuzzy command search with keyboard nav.
struct CommandPaletteView: View {
    @Environment(AppState.self) private var app
    @Environment(\.paperTheme) private var theme
    @Environment(\.openSettings) private var openSettings
    @Environment(\.renderMock) private var renderMock

    @State private var query = ""
    @State private var selection = 0
    @FocusState private var focused: Bool

    private var results: [PaperCommand] {
        let all = allCommands()
        guard !query.isEmpty else { return all }
        return all
            .compactMap { cmd -> (PaperCommand, Int)? in
                guard let score = fuzzyScore(query, cmd.title) else { return nil }
                return (cmd, score)
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
                PaletteFooter(hints: [("↑↓", "이동"), ("↵", "실행"), ("esc", "닫기")])
            }
        }
        .paletteKeyMonitor(onUp: moveUp, onDown: moveDown, onSelect: { _ in runSelected() }, onClose: close)
        .onAppear { focused = true; selection = 0 }
        .onChange(of: query) { _, _ in selection = 0 }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "command")
                .font(.system(size: 14))
                .foregroundStyle(theme.tertiaryText.color)
            if renderMock {
                Text(query.isEmpty ? "명령 검색…" : query)
                    .font(.system(size: 15))
                    .foregroundStyle(query.isEmpty ? theme.tertiaryText.color : theme.primaryText.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField("명령 검색…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.primaryText.color)
                    .focused($focused)
            }
            Text("esc")
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
                    .frame(maxHeight: 340)
                    .onChange(of: selection) { _, new in
                        withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(new, anchor: .center) }
                    }
                }
            }
        }
    }

    @ViewBuilder private func rows(_ items: [(offset: Int, element: PaperCommand)]) -> some View {
        ForEach(items, id: \.element.id) { index, cmd in
            CommandRow(command: cmd, selected: index == selection)
                .id(index)
                .onTapGesture { selection = index; runSelected() }
                .onHover { if $0 { selection = index } }
        }
        if items.isEmpty {
            Text("일치하는 명령이 없습니다")
                .font(.system(size: 13))
                .foregroundStyle(theme.tertiaryText.color)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 24)
        }
    }

    // MARK: Navigation

    private func moveUp() { if !results.isEmpty { selection = (selection - 1 + results.count) % results.count } }
    private func moveDown() { if !results.isEmpty { selection = (selection + 1) % results.count } }
    private func runSelected() {
        guard results.indices.contains(selection) else { return }
        let cmd = results[selection]
        close()
        DispatchQueue.main.async { cmd.run() }
    }
    private func close() { app.commandPaletteVisible = false }

    // MARK: Commands

    private func allCommands() -> [PaperCommand] {
        let s = app.settings
        var list: [PaperCommand] = [
            PaperCommand(title: "저장", keys: ["⌘", "S"], icon: "square.and.arrow.down") {
                if let d = app.activeDocument { _ = app.save(d) }
            },
            PaperCommand(title: "다른 이름으로 저장…", keys: ["⇧", "⌘", "S"], icon: "square.and.arrow.down.on.square") {
                if let d = app.activeDocument { _ = app.saveAs(d) }
            },
            PaperCommand(title: "모든 탭 저장", keys: ["⌥", "⌘", "S"], icon: "tray.and.arrow.down") {
                app.saveAll()
            },
            PaperCommand(title: "저장하지 않고 탭 닫기", icon: "xmark.square") {
                if let d = app.activeDocument { app.closeWithoutSaving(d) }
            },
            PaperCommand(title: s.autoSaveEnabled ? "자동 저장 끄기" : "자동 저장 켜기", icon: "clock.arrow.circlepath") {
                s.autoSaveEnabled.toggle()
            },
            PaperCommand(title: "새 문서", keys: ["⌘", "N"], icon: "doc.badge.plus") { app.newDocument() },
            PaperCommand(title: "열기…", keys: ["⌘", "O"], icon: "folder") { app.openFilePanel() },
            PaperCommand(title: "빠른 열기", keys: ["⌘", "P"], icon: "magnifyingglass") {
                app.quickOpenVisible = true
            },
            PaperCommand(title: "파일에서 찾기", keys: ["⌘", "F"], icon: "text.magnifyingglass") {
                app.findBarVisible = true
            },
            PaperCommand(title: "사이드바 표시/가리기", keys: ["⌃", "⌘", "S"], icon: "sidebar.left") {
                app.sidebarVisible.toggle()
            },
            PaperCommand(title: s.showLineNumbers ? "줄 번호 숨기기" : "줄 번호 표시", icon: "number") {
                s.showLineNumbers.toggle(); app.applySettingsToAll()
            },
            PaperCommand(title: s.lineWrap ? "줄바꿈 끄기" : "줄바꿈 켜기", icon: "arrow.turn.down.left") {
                s.lineWrap.toggle(); app.applySettingsToAll()
            },
            PaperCommand(title: "테마: 웜 페이퍼", icon: "circle.righthalf.filled") { s.themeSelection = .warmPaper },
            PaperCommand(title: "테마: 쿨 시스템", icon: "circle.righthalf.filled") { s.themeSelection = .coolSystem },
            PaperCommand(title: "테마: 다크 그레파이트", icon: "circle.fill") { s.themeSelection = .darkGraphite },
            PaperCommand(title: "테마: 시스템 자동", icon: "circle.lefthalf.filled") { s.themeSelection = .systemAuto },
            PaperCommand(title: "설정…", keys: ["⌘", ","], icon: "gearshape") { openSettings() },
        ]
        if app.activeDocument != nil {
            list.insert(PaperCommand(title: "탭 닫기", keys: ["⌘", "W"], icon: "xmark") {
                app.closeActiveDocument()
            }, at: 4)
        }
        return list
    }
}

private struct CommandRow: View {
    let command: PaperCommand
    let selected: Bool
    @Environment(\.paperTheme) private var theme

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: command.icon)
                .font(.system(size: 13))
                .foregroundStyle(selected ? theme.onAccent.color : theme.secondaryText.color)
                .frame(width: 20)
            Text(command.title)
                .font(.system(size: 13.5))
                .foregroundStyle(selected ? theme.onAccent.color : theme.primaryText.color)
            Spacer()
            if !command.keys.isEmpty {
                ShortcutChips(keys: command.keys)
                    .opacity(selected ? 0.9 : 1)
            }
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

/// Subsequence fuzzy score: substring matches rank highest, then in-order
/// character matches. Returns nil when `query` doesn't match `text`.
func fuzzyScore(_ query: String, _ text: String) -> Int? {
    let q = query.lowercased()
    let t = text.lowercased()
    if q.isEmpty { return 0 }
    if let r = t.range(of: q) {
        let start = t.distance(from: t.startIndex, to: r.lowerBound)
        return 1000 - start
    }
    var qi = q.startIndex
    var matched = 0
    for ch in t {
        if qi < q.endIndex, ch == q[qi] {
            qi = q.index(after: qi)
            matched += 1
        }
    }
    return qi == q.endIndex ? matched : nil
}
