import SwiftUI

/// Entry point. Runs the engine self-test when invoked with `--selftest`,
/// otherwise launches the SwiftUI app.
@main
enum Main {
    static func main() {
        if CommandLine.arguments.contains("--selftest") {
            exit(SelfTest.run())
        }
        if let i = CommandLine.arguments.firstIndex(of: "--render") {
            let dir = CommandLine.arguments[safe: i + 1] ?? "./render"
            exit(MainActor.assumeIsolated { RenderHarness.run(outDir: dir) })
        }
        PaperApp.main()
    }
}

@MainActor
struct PaperApp: App {
    @State private var settings: AppSettings
    @State private var app: AppState
    @State private var appearanceObserver: AppearanceObserver?

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        _app = State(initialValue: AppState(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(app)
                .environment(settings)
                .onAppear {
                    if appearanceObserver == nil {
                        appearanceObserver = AppearanceObserver(settings: settings)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1040, height: 660)
        .windowResizability(.contentMinSize)
        .commands { paperCommands }

        Settings {
            SettingsView()
                .environment(settings)
                .environment(app)
        }
    }

    @CommandsBuilder private var paperCommands: some Commands {
        // File
        CommandGroup(replacing: .newItem) {
            Button("새 문서") { app.newDocument(); app.focusActiveEditor() }
                .keyboardShortcut("n", modifiers: .command)
            Button("열기…") { app.openFilePanel() }
                .keyboardShortcut("o", modifiers: .command)
        }
        CommandGroup(replacing: .saveItem) {
            Button("저장") { if let d = app.activeDocument { _ = app.save(d) } }
                .keyboardShortcut("s", modifiers: .command)
            Button("다른 이름으로 저장…") { if let d = app.activeDocument { _ = app.saveAs(d) } }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            Button("모든 탭 저장") { app.saveAll() }
                .keyboardShortcut("s", modifiers: [.command, .option])
            Divider()
            Button("탭 닫기") { app.closeActiveDocument() }
                .keyboardShortcut("w", modifiers: .command)
        }

        // View
        CommandMenu("보기") {
            Button(app.sidebarVisible ? "사이드바 가리기" : "사이드바 보기") {
                withAnimation(.easeInOut(duration: 0.18)) { app.sidebarVisible.toggle() }
            }
            .keyboardShortcut("s", modifiers: [.command, .control])
            Toggle("줄 번호 표시", isOn: boolBinding(\.showLineNumbers))
            Toggle("줄바꿈", isOn: boolBinding(\.lineWrap))
            Divider()
            Button("글자 크게") { adjustFontSize(1) }
                .keyboardShortcut("+", modifiers: .command)
            Button("글자 작게") { adjustFontSize(-1) }
                .keyboardShortcut("-", modifiers: .command)
            Button("기본 글자 크기") { settings.fontSize = AppSettings.defaultFontSize }
                .keyboardShortcut("0", modifiers: .command)
        }

        // Go / palettes
        CommandMenu("이동") {
            Button("명령 팔레트…") { app.commandPaletteVisible = true }
                .keyboardShortcut("k", modifiers: .command)
            Button("빠른 열기…") { app.quickOpenVisible = true }
                .keyboardShortcut("p", modifiers: .command)
            Divider()
            Button("파일에서 찾기") { app.findBarVisible = true }
                .keyboardShortcut("f", modifiers: .command)
            Button("다음 탭") { app.selectNextTab(1) }
                .keyboardShortcut("]", modifiers: [.command, .shift])
            Button("이전 탭") { app.selectNextTab(-1) }
                .keyboardShortcut("[", modifiers: [.command, .shift])
        }
    }

    private func boolBinding(_ key: ReferenceWritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: key] },
            set: { settings[keyPath: key] = $0; app.applySettingsToAll() }
        )
    }

    private func adjustFontSize(_ delta: Double) {
        let new = (settings.fontSize + delta).rounded()
        settings.fontSize = min(AppSettings.maxFontSize, max(AppSettings.minFontSize, new))
    }
}
