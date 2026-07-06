import SwiftUI

/// Root layout: top bar, then sidebar + (find bar / editor / status bar),
/// with the ⌘K and ⌘P palettes overlaid.
struct ContentView: View {
    @Environment(AppState.self) private var app
    @Environment(AppSettings.self) private var settings
    @Environment(\.renderMock) private var renderMock

    private var theme: Theme { settings.activeTheme }

    var body: some View {
        ZStack(alignment: .top) {
            // Body: sidebar + editor between a reserved header strip and the footer.
            VStack(spacing: 0) {
                Color.clear.frame(height: PaperMetrics.topBarHeight)   // reserved for the header
                hDivider
                HStack(spacing: 0) {                                   // sidebar + editor row
                    if app.sidebarVisible {
                        SidebarView()
                            .frame(width: app.sidebarWidth)
                            .frame(maxHeight: .infinity)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        SidebarResizeHandle()
                    }
                    editorColumn
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                hDivider
                StatusBarView()                                        // full-width footer
            }
            // Header as a separate top layer — nothing from the body can bleed into it.
            TopBar()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .frame(minWidth: 840, minHeight: 540)
        .background(theme.windowBackground.color)
        .environment(\.paperTheme, theme)
        .preferredColorScheme(theme.colorScheme)
        .ignoresSafeArea(edges: .top)
        .overlay { overlays }
        .dropDestination(for: URL.self) { urls, _ in
            var opened = false
            for url in urls where url.isFileURL {
                if app.open(url: url) != nil { opened = true }
            }
            return opened
        }
        .background(WindowConfigurator(isDark: theme.isDark, background: theme.windowBackground.nsColor))
    }

    private var hDivider: some View {
        Rectangle().fill(theme.divider.color).frame(height: 1)
    }

    /// The editor and its find bar — bounded to the area right of the sidebar so
    /// the sidebar divider never crosses the full-width header/footer.
    private var editorColumn: some View {
        VStack(spacing: 0) {
            if app.findBarVisible {
                FindBarView()
                    .transition(.move(edge: .top).combined(with: .opacity))
                hDivider
            }
            editorArea
        }
    }

    private var editorArea: some View {
        Group {
            if renderMock {
                MockEditorView(theme: theme)
            } else if let doc = app.activeDocument {
                PaperEditor(document: doc, theme: theme)
            } else {
                theme.editorBackground.color
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var overlays: some View {
        ZStack {
            if app.commandPaletteVisible {
                CommandPaletteView().transition(.opacity)
            }
            if app.quickOpenVisible {
                QuickOpenView().transition(.opacity)
            }
        }
        .environment(\.paperTheme, theme)   // overlays don't inherit the inner .environment
        .animation(.easeOut(duration: 0.12), value: app.commandPaletteVisible)
        .animation(.easeOut(duration: 0.12), value: app.quickOpenVisible)
    }
}
