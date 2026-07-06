import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// Central app coordinator: open tabs, sidebar data, overlay visibility, and all
/// file operations. Owns the per-document editor controllers.
@MainActor
@Observable
final class AppState {
    let settings: AppSettings

    // Open tabs
    var documents: [TextDocument] = []
    var activeDocumentID: UUID?

    // Layout / overlays
    var sidebarVisible = true
    var findBarVisible = false
    var commandPaletteVisible = false
    var quickOpenVisible = false

    // Sidebar
    var recentFiles: [RecentFile] = []
    var folders: [SidebarFolder] = []
    var sidebarSearch = ""
    var sidebarWidth: Double = 242
    var expandedFolders: Set<String> = []   // paths of expanded folders (any depth)

    static let minSidebarWidth: Double = 180
    static let maxSidebarWidth: Double = 480

    /// Live-updates the sidebar width during a drag (clamped).
    func setSidebarWidth(_ width: Double) {
        sidebarWidth = min(Self.maxSidebarWidth, max(Self.minSidebarWidth, width))
    }

    /// Persists the sidebar width (called when a resize drag ends).
    func persistSidebarWidth() {
        UserDefaults.standard.set(sidebarWidth, forKey: "sidebarWidth")
    }

    private func loadSidebarWidth() {
        let w = UserDefaults.standard.double(forKey: "sidebarWidth")
        if w > 0 { sidebarWidth = min(Self.maxSidebarWidth, max(Self.minSidebarWidth, w)) }
    }

    func toggleFolder(_ path: String) {
        if expandedFolders.contains(path) { expandedFolders.remove(path) }
        else { expandedFolders.insert(path) }
    }

    func isFolderExpanded(_ path: String) -> Bool { expandedFolders.contains(path) }

    /// One live AppKit editor per open document (preserves undo, scroll, selection).
    @ObservationIgnored var controllers: [UUID: EditorController] = [:]
    @ObservationIgnored private var autoSaveTimer: Timer?

    init(settings: AppSettings) {
        self.settings = settings
        loadRecents()
        loadFolders()
        loadSidebarWidth()
        newDocument()
        configureAutoSave()
        observeAutoSaveSettings()
        observeEditorSettings()
    }

    /// Pushes font/wrap/line-number/theme changes into the live editors immediately,
    /// independent of any SwiftUI re-render.
    private func observeEditorSettings() {
        withObservationTracking {
            _ = settings.fontName; _ = settings.fontSize; _ = settings.tabWidth
            _ = settings.showLineNumbers; _ = settings.lineWrap
            _ = settings.themeSelection; _ = settings.useCustomAccent
            _ = settings.customAccent; _ = settings.systemIsDark
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.applySettingsToAll()
                self.applyThemeToAll()
                self.observeEditorSettings()
            }
        }
    }

    var activeDocument: TextDocument? {
        guard let id = activeDocumentID else { return nil }
        return documents.first { $0.id == id }
    }

    // MARK: Editor controllers

    func controller(for doc: TextDocument) -> EditorController {
        if let c = controllers[doc.id] { return c }
        let c = EditorController(document: doc, settings: settings, theme: settings.activeTheme)
        c.onOpenFiles = { [weak self] urls in
            guard let self else { return false }
            var any = false
            for url in urls where url.isFileURL {
                if self.open(url: url) != nil { any = true }
            }
            return any
        }
        controllers[doc.id] = c
        return c
    }

    /// Pushes live text-view content back into the document model.
    func syncToModel(_ doc: TextDocument) {
        controllers[doc.id]?.syncToModel()
    }

    func focusActiveEditor() {
        guard let doc = activeDocument else { return }
        controllers[doc.id]?.focus()
    }

    func applyThemeToAll() {
        let theme = settings.activeTheme
        for c in controllers.values { c.applyThemeIfNeeded(theme) }
    }

    func applySettingsToAll() {
        for c in controllers.values { c.applySettingsIfNeeded() }
    }

    // MARK: Tabs

    @discardableResult
    func newDocument(welcome: Bool = false) -> TextDocument {
        let doc = TextDocument(
            url: nil,
            text: welcome ? Self.welcomeText : "",
            encoding: settings.defaultEncoding,
            lineEnding: settings.defaultLineEnding,
            untitledNumber: nextUntitledNumber()
        )
        documents.append(doc)
        activeDocumentID = doc.id
        return doc
    }

    func selectDocument(_ doc: TextDocument) {
        activeDocumentID = doc.id
    }

    func selectNextTab(_ delta: Int) {
        guard let id = activeDocumentID,
              let idx = documents.firstIndex(where: { $0.id == id }),
              !documents.isEmpty else { return }
        let next = (idx + delta + documents.count) % documents.count
        activeDocumentID = documents[next].id
    }

    private func nextUntitledNumber() -> Int {
        let used = Set(documents.filter { $0.isUntitled }.map { $0.untitledNumber })
        var n = 1
        while used.contains(n) { n += 1 }
        return n
    }

    // MARK: Open

    func openFilePanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "파일 열기"
        if panel.runModal() == .OK {
            for url in panel.urls { open(url: url) }
        }
    }

    @discardableResult
    func open(url: URL, inNewTab: Bool = true) -> TextDocument? {
        if let existing = documents.first(where: { $0.url == url }) {
            activeDocumentID = existing.id
            return existing
        }
        guard let data = try? Data(contentsOf: url) else {
            presentError("파일을 열 수 없습니다", "‘\(url.lastPathComponent)’을(를) 읽지 못했습니다.")
            return nil
        }
        let decoded = FileCodec.decode(data, preferred: settings.defaultEncoding)
        let doc = TextDocument(url: url, text: decoded.text, encoding: decoded.encoding, lineEnding: decoded.lineEnding)
        doc.characterCount = decoded.text.count

        // Replace a single pristine untitled tab rather than stacking on top of it.
        if let only = documents.first, documents.count == 1, only.isUntitled, !only.isDirty,
           controllers[only.id]?.isEmpty ?? only.text.isEmpty {
            controllers[only.id]?.teardown()
            controllers[only.id] = nil
            documents = [doc]
        } else {
            documents.append(doc)
        }
        activeDocumentID = doc.id
        addRecent(url)
        return doc
    }

    // MARK: Save

    @discardableResult
    func save(_ doc: TextDocument) -> Bool {
        syncToModel(doc)
        guard let url = doc.url else { return saveAs(doc) }
        return write(doc, to: url)
    }

    @discardableResult
    func saveAs(_ doc: TextDocument) -> Bool {
        syncToModel(doc)
        let panel = NSSavePanel()
        panel.title = "다른 이름으로 저장"
        var name = doc.displayName
        if !name.contains(".") { name += ".txt" }
        panel.nameFieldStringValue = name
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        doc.url = url
        let ok = write(doc, to: url)
        if ok { addRecent(url) }
        return ok
    }

    func saveAll() {
        for doc in documents where doc.isDirty || (doc.isUntitled && !(controllers[doc.id]?.isEmpty ?? true)) {
            _ = save(doc)
        }
    }

    @discardableResult
    private func write(_ doc: TextDocument, to url: URL) -> Bool {
        guard let data = FileCodec.encode(doc.text, encoding: doc.encoding, lineEnding: doc.lineEnding) else {
            presentError("저장할 수 없습니다",
                         "현재 내용을 ‘\(doc.encoding.displayName)’(으)로 변환할 수 없습니다. 다른 인코딩(예: UTF-8)을 선택하세요.")
            return false
        }
        do {
            try data.write(to: url, options: .atomic)
            doc.isDirty = false
            return true
        } catch {
            presentError("저장 실패", error.localizedDescription)
            return false
        }
    }

    // MARK: Close

    func closeDocument(_ doc: TextDocument) {
        if doc.isDirty {
            let alert = NSAlert()
            alert.messageText = "‘\(doc.displayName)’의 변경 사항을 저장하시겠습니까?"
            alert.informativeText = "저장하지 않으면 변경 사항이 사라집니다."
            alert.addButton(withTitle: "저장")
            alert.addButton(withTitle: "저장 안 함")
            alert.addButton(withTitle: "취소")
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                if !save(doc) { return }        // save cancelled/failed → keep tab
            case .alertSecondButtonReturn:
                break                            // discard
            default:
                return                           // cancel
            }
        }
        removeTab(doc)
    }

    func closeActiveDocument() {
        if let doc = activeDocument { closeDocument(doc) }
    }

    /// Discards any unsaved changes and closes the tab (used by the ⌘K palette).
    func closeWithoutSaving(_ doc: TextDocument) {
        removeTab(doc)
    }

    private func removeTab(_ doc: TextDocument) {
        controllers[doc.id]?.teardown()
        controllers[doc.id] = nil
        guard let idx = documents.firstIndex(of: doc) else { return }
        documents.remove(at: idx)
        if activeDocumentID == doc.id {
            activeDocumentID = (documents[safe: idx] ?? documents.last)?.id
        }
        if documents.isEmpty { newDocument() }
    }

    // MARK: Recents

    func addRecent(_ url: URL) {
        recentFiles.removeAll { $0.url == url }
        recentFiles.insert(RecentFile(url: url), at: 0)
        if recentFiles.count > 20 { recentFiles = Array(recentFiles.prefix(20)) }
        persistRecents()
    }

    /// Removes an entry from the "최근 항목" list only — does not delete the file.
    func removeRecent(_ url: URL) {
        recentFiles.removeAll { $0.url == url }
        persistRecents()
    }

    func clearRecents() {
        recentFiles.removeAll()
        persistRecents()
    }

    private func persistRecents() {
        UserDefaults.standard.set(recentFiles.map(\.url.path), forKey: "recentFiles")
    }

    private func loadRecents() {
        let paths = UserDefaults.standard.stringArray(forKey: "recentFiles") ?? []
        recentFiles = paths.map { RecentFile(url: URL(fileURLWithPath: $0)) }
            .filter { FileManager.default.fileExists(atPath: $0.url.path) }
    }

    // MARK: Folders

    func addFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.title = "폴더 추가"
        panel.prompt = "추가"
        if panel.runModal() == .OK, let url = panel.url {
            guard !folders.contains(where: { $0.url == url }) else { return }
            folders.append(SidebarFolder(url: url, count: Self.textFileCount(in: url)))
            saveFolders()
        }
    }

    func removeFolder(_ folder: SidebarFolder) {
        folders.removeAll { $0.id == folder.id }
        saveFolders()
    }

    private func loadFolders() {
        let paths = UserDefaults.standard.stringArray(forKey: "folderBookmarks") ?? []
        folders = paths.compactMap { path in
            let url = URL(fileURLWithPath: path)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return nil }
            return SidebarFolder(url: url, count: Self.textFileCount(in: url))
        }
    }

    private func saveFolders() {
        UserDefaults.standard.set(folders.map(\.url.path), forKey: "folderBookmarks")
    }

    private static func textFileCount(in url: URL) -> Int {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return 0 }
        return items.filter { $0.looksLikeTextFile }.count
    }

    func textFiles(in folder: SidebarFolder) -> [RecentFile] {
        entries(in: folder.url).filter { !$0.isDirectory }.map { RecentFile(url: $0.url) }
    }

    /// Subfolders and text files inside `url`, folders first then files, each sorted by name.
    func entries(in url: URL) -> [FolderEntry] {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return [] }
        let mapped: [FolderEntry] = items.compactMap { item in
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir { return FolderEntry(url: item, isDirectory: true) }
            return item.looksLikeTextFile ? FolderEntry(url: item, isDirectory: false) : nil
        }
        return mapped.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }   // folders first
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    func removeFolder(url: URL) {
        folders.removeAll { $0.url == url }
        saveFolders()
    }

    // MARK: Auto-save

    private func observeAutoSaveSettings() {
        withObservationTracking {
            _ = settings.autoSaveEnabled
            _ = settings.autoSaveInterval
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.configureAutoSave()
                self?.observeAutoSaveSettings()
            }
        }
    }

    private func configureAutoSave() {
        autoSaveTimer?.invalidate()
        guard settings.autoSaveEnabled else { return }
        let interval = TimeInterval(max(2, settings.autoSaveInterval))
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.autoSaveTick() }
        }
    }

    private func autoSaveTick() {
        for doc in documents where doc.isDirty && doc.url != nil {
            _ = save(doc)
        }
    }

    // MARK: Errors

    private func presentError(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "확인")
        alert.runModal()
    }

    // MARK: Welcome content

    static let welcomeText = """
    2026-07-05 제품 회의록

    참석: 지민, 하늘, 서준
    장소: 3층 회의실 B

    안건
    1. 7월 릴리스 범위 확정
    2. 자동 저장 주기 조정 (30초 -> 10초)
    3. 인코딩 감지 실패 사례 검토

    결정 사항
    - 릴리스는 7월 18일(금)로 확정
    - 상태바에 줄바꿈 형식(LF/CRLF) 표시 추가
    - EUC-KR 파일은 열 때 변환 여부를 묻는다

    할 일
    [ ] 지민: 자동 저장 성능 측정
    [ ] 하늘: 탭 복원 시나리오 정리
    [ ] 서준: 베타 피드백 분류
    """
}
