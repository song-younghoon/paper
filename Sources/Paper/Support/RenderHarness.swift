import SwiftUI
import AppKit

// MARK: - Render-mock environment

/// When true, views substitute AppKit-backed pieces (the editor, window config)
/// with pure-SwiftUI stand-ins so `ImageRenderer` can produce a faithful preview
/// off-screen (used by `--render` for visual self-verification).
private struct RenderMockKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var renderMock: Bool {
        get { self[RenderMockKey.self] }
        set { self[RenderMockKey.self] = newValue }
    }
}

/// A pure-SwiftUI approximation of the editor (line numbers + text) for previews.
struct MockEditorView: View {
    let theme: Theme
    @Environment(AppSettings.self) private var settings

    private var lines: [String] { AppState.welcomeText.components(separatedBy: "\n") }
    private var lineHeight: CGFloat { CGFloat(settings.fontSize) * 1.5 }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if settings.showLineNumbers {
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { i, _ in
                        Text("\(i + 1)")
                            .font(.system(size: CGFloat(settings.fontSize) * 0.86, weight: .regular, design: .monospaced))
                            .foregroundStyle(i == 0 ? theme.lineNumberActive.color : theme.lineNumber.color)
                            .frame(height: lineHeight, alignment: .trailing)
                    }
                }
                .padding(.trailing, 9)
                .padding(.top, 10)
                .frame(width: 46, alignment: .trailing)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                    Text(line.isEmpty ? " " : line)
                        .font(.system(size: CGFloat(settings.fontSize)))
                        .foregroundStyle(theme.primaryText.color)
                        .frame(height: lineHeight, alignment: .leading)
                        .background(i == 0 ? theme.currentLine.color : .clear)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 6)
            .padding(.top, 10)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.editorBackground.color)
    }
}

// MARK: - Harness

/// Preview of the General settings tab's custom controls (theme cards + accent),
/// without the AppKit-backed Form/TabView so `ImageRenderer` can render them.
struct SettingsThemePreview: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 18) {
            Text("테마").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                ForEach(ThemeSelection.allCases) { sel in
                    ThemeCard(selection: sel, isSelected: settings.themeSelection == sel) {
                        settings.themeSelection = sel
                    }
                }
            }
            Text("강조 색상").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach(AccentSwatch.presets) { swatch in
                    AccentDot(color: swatch.color,
                              selected: settings.customAccent.hexString == swatch.color.hexString) {
                        settings.customAccent = swatch.color
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(white: 0.96))
    }
}

/// The app icon, drawn in SwiftUI so it can be rendered to PNG → .icns.
struct AppIconView: View {
    var body: some View {
        ZStack {
            // Warm amber squircle background.
            RoundedRectangle(cornerRadius: 230, style: .continuous)
                .fill(LinearGradient(
                    colors: [PaperColor(hex: 0xE0A84A).color, PaperColor(hex: 0xB77F33).color],
                    startPoint: .top, endPoint: .bottom))

            // A paper page with text lines (one amber = the active line).
            RoundedRectangle(cornerRadius: 72, style: .continuous)
                .fill(PaperColor(hex: 0xFCFAF4).color)
                .frame(width: 520, height: 664)
                .shadow(color: .black.opacity(0.18), radius: 34, y: 18)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 46) {
                        line(0.60, PaperColor(hex: 0xB77F33).color, height: 30)
                        line(0.85, PaperColor(hex: 0xCFC7B6).color)
                        line(0.72, PaperColor(hex: 0xCFC7B6).color)
                        line(0.80, PaperColor(hex: 0xCFC7B6).color)
                        line(0.52, PaperColor(hex: 0xCFC7B6).color)
                    }
                    .padding(64)
                }
        }
        .frame(width: 1024, height: 1024)
    }

    private func line(_ fraction: CGFloat, _ color: Color, height: CGFloat = 26) -> some View {
        Capsule().fill(color)
            .frame(width: 392 * fraction, height: height)
    }
}

/// Diagnostic: renders a folder tree pre-expanded so nested-folder display can be
/// verified without simulating clicks.
struct FolderTreeTest: View {
    let folder: SidebarFolder
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            FolderNode(url: folder.url, count: folder.count, depth: 0, isRoot: true, query: "")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(8)
        .background(theme.sidebarBackground.color)
        .environment(\.paperTheme, theme)
    }
}

enum RenderHarness {
    @MainActor
    static func run(outDir: String) -> Int32 {
        _ = NSApplication.shared
        let fm = FileManager.default
        try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        print("Rendering previews → \(outDir)")

        func render(_ name: String, _ size: CGSize, _ view: AnyView) {
            let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
            renderer.scale = 2
            guard let img = renderer.nsImage,
                  let tiff = img.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else {
                print("  ✗ \(name)"); return
            }
            let url = URL(fileURLWithPath: outDir).appendingPathComponent("\(name).png")
            do { try png.write(to: url); print("  ✓ \(name).png") }
            catch { print("  ✗ \(name): \(error)") }
        }

        func mainWindow(_ theme: ThemeSelection, sidebar: Bool = true, find: Bool = false,
                        palette: Bool = false, quickOpen: Bool = false) -> (AppState, AppSettings) {
            let s = AppSettings()
            s.themeSelection = theme
            let a = AppState(settings: s)
            a.sidebarVisible = sidebar
            a.findBarVisible = find
            a.commandPaletteVisible = palette
            a.quickOpenVisible = quickOpen
            // Seed a couple of recents + a folder so the sidebar isn't empty.
            a.recentFiles = [
                RecentFile(url: URL(fileURLWithPath: "/Users/x/문서/메모/회의록 2026-07-05.txt")),
                RecentFile(url: URL(fileURLWithPath: "/Users/x/문서/프로젝트/배포 체크리스트.txt")),
                RecentFile(url: URL(fileURLWithPath: "/Users/x/문서/아이디어 스케치.txt")),
            ]
            a.folders = [
                SidebarFolder(url: URL(fileURLWithPath: "/Users/x/메모"), count: 12),
                SidebarFolder(url: URL(fileURLWithPath: "/Users/x/프로젝트"), count: 8),
                SidebarFolder(url: URL(fileURLWithPath: "/Users/x/보관함"), count: 34),
            ]
            return (a, s)
        }

        let bigSize = CGSize(width: 1000, height: 640)

        for sel in [ThemeSelection.warmPaper, .coolSystem, .darkGraphite] {
            let (a, s) = mainWindow(sel)
            render("main-\(sel.rawValue)", bigSize, AnyView(
                ContentView().environment(a).environment(s).environment(\.renderMock, true)
            ))
        }

        // Find bar (cool)
        let (af, sf) = mainWindow(.coolSystem, find: true)
        render("findbar", bigSize, AnyView(
            ContentView().environment(af).environment(sf).environment(\.renderMock, true)
        ))

        // Command palette (dark)
        let (ak, sk) = mainWindow(.darkGraphite, palette: true)
        render("palette-command", bigSize, AnyView(
            ContentView().environment(ak).environment(sk).environment(\.renderMock, true)
        ))

        // Quick open (warm)
        let (ap, sp) = mainWindow(.warmPaper, quickOpen: true)
        render("palette-quickopen", bigSize, AnyView(
            ContentView().environment(ap).environment(sp).environment(\.renderMock, true)
        ))

        // Full real window (real NSTextView included) via NSHostingView + cacheDisplay.
        func renderFullWindow(_ sel: ThemeSelection, sidebar: Bool, name: String) {
            let s = AppSettings(); s.themeSelection = sel
            let a = AppState(settings: s)
            a.sidebarVisible = sidebar
            a.documents.first?.text = AppState.welcomeText
            a.recentFiles = [
                RecentFile(url: URL(fileURLWithPath: "/Users/x/문서/메모/회의록 2026-07-05.txt")),
                RecentFile(url: URL(fileURLWithPath: "/Users/x/문서/배포 체크리스트.txt")),
            ]
            a.folders = [SidebarFolder(url: URL(fileURLWithPath: "/Users/x/메모"), count: 12)]

            let size = NSSize(width: 1000, height: 640)
            let hosting = NSHostingView(rootView: AnyView(
                ContentView().environment(a).environment(s)
            ))
            hosting.frame = NSRect(origin: .zero, size: size)
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                                  styleMask: [.titled, .fullSizeContentView],
                                  backing: .buffered, defer: false)
            window.contentView = hosting
            hosting.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
            hosting.layoutSubtreeIfNeeded()

            guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
            hosting.cacheDisplay(in: hosting.bounds, to: rep)
            guard let png = rep.representation(using: .png, properties: [:]) else { print("  ✗ \(name)"); return }
            try? png.write(to: URL(fileURLWithPath: outDir).appendingPathComponent("\(name).png"))
            print("  ✓ \(name).png")
        }
        renderFullWindow(.warmPaper, sidebar: true, name: "window-warm")
        renderFullWindow(.warmPaper, sidebar: false, name: "window-nosidebar")

        // Nested-folder diagnostic: build a real tree, render it pre-expanded.
        let tree = URL(fileURLWithPath: outDir).appendingPathComponent("sample-tree")
        let memo = tree.appendingPathComponent("메모")
        let y2026 = memo.appendingPathComponent("2026")
        try? fm.createDirectory(at: y2026, withIntermediateDirectories: true)
        try? "x".write(to: tree.appendingPathComponent("루트.txt"), atomically: true, encoding: .utf8)
        try? "x".write(to: memo.appendingPathComponent("회의.txt"), atomically: true, encoding: .utf8)
        try? "x".write(to: memo.appendingPathComponent("일지.txt"), atomically: true, encoding: .utf8)
        try? "x".write(to: y2026.appendingPathComponent("1월.txt"), atomically: true, encoding: .utf8)
        let treeApp = AppState(settings: AppSettings())
        treeApp.expandedFolders = [tree.path, memo.path]
        render("folder-tree", CGSize(width: 280, height: 440), AnyView(
            FolderTreeTest(folder: SidebarFolder(url: tree, count: 1), theme: .warmPaper)
                .environment(treeApp)
        ))

        // App icon
        render("appicon", CGSize(width: 1024, height: 1024), AnyView(AppIconView()))

        // Real AppKit editor (NSTextView + ruler) via cacheDisplay — the one piece
        // ImageRenderer can't draw.
        func renderRealEditor(_ sel: ThemeSelection) {
            let s = AppSettings(); s.themeSelection = sel
            let a = AppState(settings: s)
            guard let doc = a.activeDocument else { return }
            doc.text = AppState.welcomeText
            let controller = a.controller(for: doc)
            let scroll = controller.scrollView
            let size = NSSize(width: 900, height: 600)

            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = scroll
            controller.applyTheme(s.activeTheme)
            controller.applySettings()
            scroll.frame = NSRect(origin: .zero, size: size)
            scroll.layoutSubtreeIfNeeded()
            if let container = controller.textView.textContainer {
                controller.textView.layoutManager?.ensureLayout(for: container)
            }
            scroll.tile()
            scroll.verticalRulerView?.needsDisplay = true
            scroll.displayIfNeeded()

            guard let rep = scroll.bitmapImageRepForCachingDisplay(in: scroll.bounds) else { return }
            scroll.cacheDisplay(in: scroll.bounds, to: rep)
            guard let png = rep.representation(using: .png, properties: [:]) else {
                print("  ✗ editor-\(sel.rawValue)"); return
            }
            let url = URL(fileURLWithPath: outDir).appendingPathComponent("editor-\(sel.rawValue).png")
            try? png.write(to: url)
            print("  ✓ editor-\(sel.rawValue).png")
        }
        renderRealEditor(.warmPaper)
        renderRealEditor(.darkGraphite)

        // Settings — custom controls only (Form/TabView don't render in ImageRenderer).
        let ss = AppSettings(); ss.themeSelection = .coolSystem; ss.useCustomAccent = true
        render("settings-theme", CGSize(width: 520, height: 380), AnyView(
            SettingsThemePreview().environment(ss).environment(\.renderMock, true)
        ))

        return 0
    }
}
