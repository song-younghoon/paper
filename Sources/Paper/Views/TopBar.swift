import SwiftUI

/// The titlebar-region bar: sidebar toggle, document tabs, find, and ⌘K.
struct TopBar: View {
    @Environment(AppState.self) private var app
    @Environment(\.paperTheme) private var theme
    @Environment(\.renderMock) private var renderMock

    var body: some View {
        HStack(spacing: 6) {
            IconButton(systemName: "sidebar.left", help: "사이드바 (⌃⌘S)") {
                withAnimation(.easeInOut(duration: 0.18)) { app.sidebarVisible.toggle() }
            }
            TabBarView()
            Spacer(minLength: 8)
            IconButton(systemName: "magnifyingglass", help: "파일에서 찾기 (⌘F)") {
                app.findBarVisible.toggle()
            }
            KeyHintPill(text: "⌘K") { app.commandPaletteVisible = true }
        }
        .padding(.leading, 78)   // clearance for the traffic lights
        .padding(.trailing, 12)
        .frame(height: PaperMetrics.topBarHeight)
        .background(
            ZStack {
                theme.toolbarBackground.color
                if !renderMock {
                    WindowDragHandle()   // empty regions drag the window
                }
            }
        )
    }
}

struct TabBarView: View {
    @Environment(AppState.self) private var app
    @Environment(\.paperTheme) private var theme
    @Environment(\.renderMock) private var renderMock

    var body: some View {
        if renderMock {
            tabs
        } else {
            ScrollView(.horizontal, showsIndicators: false) { tabs }
        }
    }

    private var tabs: some View {
        HStack(spacing: 4) {
            ForEach(app.documents) { doc in
                TabItemView(
                    document: doc,
                    isActive: doc.id == app.activeDocumentID,
                    select: { app.selectDocument(doc) },
                    close: { app.closeDocument(doc) }
                )
            }
            IconButton(systemName: "plus", help: "새 문서 (⌘N)") { app.newDocument() }
        }
    }
}

struct TabItemView: View {
    let document: TextDocument
    let isActive: Bool
    let select: () -> Void
    let close: () -> Void

    @Environment(\.paperTheme) private var theme
    @State private var hovering = false
    @State private var closeHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text")
                .font(.system(size: 11))
                .foregroundStyle(isActive ? theme.accent.color : theme.tertiaryText.color)

            Text(document.displayName)
                .font(.system(size: 12.5))
                .foregroundStyle(isActive ? theme.primaryText.color : theme.secondaryText.color)
                .lineLimit(1)

            trailing
                .frame(width: 16, height: 16)
        }
        .padding(.leading, 11)
        .padding(.trailing, 6)
        .frame(height: 30)
        .frame(minWidth: 118, maxWidth: 196)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isActive ? theme.editorBackground.color
                               : (hovering ? theme.primaryText.color.opacity(0.05) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(isActive ? theme.divider.color : Color.clear, lineWidth: 1)
        )
        .shadow(color: .black.opacity(isActive ? 0.05 : 0), radius: 2, y: 1)
        .contentShape(Rectangle())
        .onTapGesture(perform: select)
        .onHover { hovering = $0 }
    }

    @ViewBuilder private var trailing: some View {
        if document.isDirty && !hovering {
            Circle()
                .fill(theme.secondaryText.color)
                .frame(width: 7, height: 7)
        } else if isActive || hovering {
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(theme.secondaryText.color)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(theme.primaryText.color.opacity(closeHovering ? 0.14 : 0)))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { closeHovering = $0 }
        } else {
            Color.clear
        }
    }
}
