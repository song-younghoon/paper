import SwiftUI

/// The find & replace bar (design 1b). Drives the active document's controller.
struct FindBarView: View {
    @Environment(AppState.self) private var app
    @Environment(\.paperTheme) private var theme

    @Environment(\.renderMock) private var renderMock
    @State private var query = ""
    @State private var replacement = ""
    @State private var options = FindOptions()
    @State private var result = FindResult()
    @FocusState private var focus: Field?

    private enum Field { case find, replace }

    private var controller: EditorController? {
        app.activeDocument.map { app.controller(for: $0) }
    }

    var body: some View {
        VStack(spacing: 6) {
            findRow
            replaceRow
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.toolbarBackground.color)
        .onAppear {
            focus = .find
            runSearch()
        }
        .onChange(of: query) { _, _ in runSearch() }
        .onChange(of: options) { _, _ in runSearch() }
        .onChange(of: app.activeDocumentID) { _, _ in runSearch() }
        .onExitCommand { close() }
    }

    // MARK: Rows

    private var findRow: some View {
        HStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.tertiaryText.color)
                if renderMock {
                    Text("자동 저장")
                        .font(.system(size: 12.5))
                        .foregroundStyle(theme.primaryText.color)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("1/2")
                        .font(.system(size: 11.5))
                        .foregroundStyle(theme.tertiaryText.color)
                        .monospacedDigit()
                } else {
                    TextField("찾기", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                        .foregroundStyle(theme.primaryText.color)
                        .focused($focus, equals: .find)
                        .onSubmit { next() }

                    if !query.isEmpty {
                        Text(result.total > 0 ? "\(result.current)/\(result.total)" : "0/0")
                            .font(.system(size: 11.5))
                            .foregroundStyle(theme.tertiaryText.color)
                            .monospacedDigit()
                    }
                }
                navButton("chevron.up") { previous() }
                navButton("chevron.down") { next() }

                Rectangle().fill(theme.divider.color).frame(width: 1, height: 16)

                FindToggle(label: "Aa", active: options.caseSensitive, help: "대소문자 구분") {
                    options.caseSensitive.toggle()
                }
                FindToggle(label: ".*", active: options.regex, help: "정규식") {
                    options.regex.toggle()
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(theme.controlBackground.color))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(theme.divider.color, lineWidth: 1))

            IconButton(systemName: "xmark", help: "닫기 (esc)") { close() }
        }
    }

    private var replaceRow: some View {
        HStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.2.squarepath")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.tertiaryText.color)
                if renderMock {
                    Text("자동 백업")
                        .font(.system(size: 12.5))
                        .foregroundStyle(theme.primaryText.color)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    TextField("바꾸기", text: $replacement)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                        .foregroundStyle(theme.primaryText.color)
                        .focused($focus, equals: .replace)
                        .onSubmit { replaceOne() }
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(theme.controlBackground.color))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(theme.divider.color, lineWidth: 1))

            PillButton(title: "바꾸기") { replaceOne() }
            PillButton(title: "모두 바꾸기") { replaceAll() }
        }
    }

    private func navButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.secondaryText.color)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .disabled(result.total == 0)
    }

    // MARK: Actions

    private func runSearch() {
        result = controller?.updateSearch(query: query, options: options) ?? FindResult()
    }
    private func next() { result = controller?.moveToMatch(forward: true) ?? FindResult() }
    private func previous() { result = controller?.moveToMatch(forward: false) ?? FindResult() }
    private func replaceOne() {
        result = controller?.replaceCurrent(with: replacement, query: query, options: options) ?? FindResult()
    }
    private func replaceAll() {
        _ = controller?.replaceAll(query: query, replacement: replacement, options: options)
        runSearch()
    }
    private func close() {
        controller?.endFind()
        app.findBarVisible = false
        app.focusActiveEditor()
    }
}

/// A small toggle chip ("Aa" / ".*") in the find field.
private struct FindToggle: View {
    let label: String
    let active: Bool
    let help: String
    let action: () -> Void
    @Environment(\.paperTheme) private var theme

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(active ? theme.onAccent.color : theme.secondaryText.color)
                .frame(width: 24, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(active ? theme.accent.color : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// A small bordered action button ("바꾸기" / "모두 바꾸기").
struct PillButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.paperTheme) private var theme
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(theme.primaryText.color)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(theme.controlBackground.color.opacity(hovering ? 1 : 0.7))
                )
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(theme.divider.color, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
