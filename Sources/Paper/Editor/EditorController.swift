import AppKit

/// Options for a find/replace operation.
struct FindOptions: Equatable {
    var caseSensitive = false
    var regex = false
}

/// Match position for the find bar's "n/총 m" readout.
struct FindResult: Equatable {
    var current = 0
    var total = 0
}

/// Owns one document's live AppKit text stack (TextKit 1, for a reliable ruler)
/// and mediates between the model and the view. One controller per open tab, so
/// undo history, scroll position, and selection survive tab switches.
@MainActor
final class EditorController: NSObject, NSTextViewDelegate {
    let document: TextDocument
    let settings: AppSettings
    private(set) var theme: Theme

    let scrollView: NSScrollView
    let textView: PaperTextView
    private let textStorage: NSTextStorage
    private let ruler: LineNumberRulerView

    var lineIndex = LineIndex()

    /// Forwarded to the text view so dropped files open as tabs.
    var onOpenFiles: (([URL]) -> Bool)? {
        didSet { textView.onOpenFiles = onOpenFiles }
    }

    private var paragraphStyle = NSMutableParagraphStyle()
    private var isLoadingContent = false
    private var appliedThemeSig = ""
    private var appliedSettingsSig = ""

    // Find state
    private var matches: [NSRange] = []
    private var currentMatchIndex = -1

    init(document: TextDocument, settings: AppSettings, theme: Theme) {
        self.document = document
        self.settings = settings
        self.theme = theme

        // TextKit 1 stack — explicit construction guarantees NSLayoutManager.
        textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: NSSize(width: 200, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)

        textView = PaperTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 200), textContainer: container)

        scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.autoresizingMask = [.width, .height]

        ruler = LineNumberRulerView(textView: textView, scrollView: scrollView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true

        super.init()

        ruler.controller = self
        configureTextView()
        textView.delegate = self
        applySettings()
        applyTheme(theme)
        loadContent()
        installObservers()
    }

    // MARK: Configuration

    private func configureTextView() {
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.usesFontPanel = false
        textView.usesFindBar = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.textContainerInset = NSSize(width: 6, height: 10)
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)
    }

    /// Wrap on/off: track the view width (wrap) or grow horizontally (no wrap).
    private func configureWrap() {
        let wrap = settings.lineWrap
        guard let container = textView.textContainer else { return }
        container.widthTracksTextView = wrap
        if wrap {
            let width = scrollView.contentSize.width
            container.size = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            textView.isHorizontallyResizable = false
            textView.autoresizingMask = [.width]
            scrollView.hasHorizontalScroller = false
        } else {
            container.size = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.isHorizontallyResizable = true
            textView.autoresizingMask = []
            scrollView.hasHorizontalScroller = true
        }
        textView.needsLayout = true
        ruler.needsDisplay = true
    }

    /// Reapplies theme only when the visible palette actually changed.
    func applyThemeIfNeeded(_ newTheme: Theme) {
        theme = newTheme
        let sig = "\(newTheme.id)|\(newTheme.accent.hexString)|\(newTheme.selection.hexString)|\(newTheme.editorBackground.hexString)"
        guard sig != appliedThemeSig else { return }
        appliedThemeSig = sig
        applyTheme(newTheme)
    }

    /// Reapplies settings only when a rendering-relevant preference changed.
    func applySettingsIfNeeded() {
        let sig = "\(settings.fontName)|\(settings.fontSize)|\(settings.tabWidth)|\(settings.showLineNumbers)|\(settings.lineWrap)"
        guard sig != appliedSettingsSig else { return }
        appliedSettingsSig = sig
        applySettings()
    }

    /// Applies font, tab width, wrap, and line-number visibility from settings.
    func applySettings() {
        let font = settings.editorFont
        paragraphStyle = NSMutableParagraphStyle()
        let spaceWidth = (" " as NSString).size(withAttributes: [.font: font]).width
        paragraphStyle.defaultTabInterval = spaceWidth * CGFloat(max(1, settings.tabWidth))
        paragraphStyle.tabStops = []

        textView.font = font
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes = currentAttributes()
        reapplyAttributes()

        ruler.font = settings.lineNumberFont
        scrollView.rulersVisible = settings.showLineNumbers
        ruler.updateThickness(lineCount: lineIndex.lineCount)
        ruler.needsDisplay = true
        configureWrap()
        textView.needsDisplay = true
    }

    /// Applies theme colors to the text view, ruler, selection, and caret.
    func applyTheme(_ newTheme: Theme) {
        theme = newTheme
        let bg = theme.editorBackground.nsColor
        scrollView.backgroundColor = bg
        scrollView.drawsBackground = true
        textView.editorBackgroundColor = bg
        textView.currentLineColor = theme.currentLine.nsColor
        textView.insertionPointColor = theme.accent.nsColor
        textView.selectedTextAttributes = [.backgroundColor: theme.selection.nsColor]
        textView.textColor = theme.primaryText.nsColor

        let full = NSRange(location: 0, length: textStorage.length)
        if full.length > 0 {
            textStorage.addAttribute(.foregroundColor, value: theme.primaryText.nsColor, range: full)
        }
        var typing = textView.typingAttributes
        typing[.foregroundColor] = theme.primaryText.nsColor
        textView.typingAttributes = typing

        ruler.backgroundColor = theme.editorBackground.nsColor
        ruler.textColor = theme.lineNumber.nsColor
        ruler.activeTextColor = theme.lineNumberActive.nsColor
        ruler.dividerColor = theme.divider.opacity(0.6).nsColor

        ruler.needsDisplay = true
        textView.needsDisplay = true
        scrollView.needsDisplay = true
    }

    private func currentAttributes() -> [NSAttributedString.Key: Any] {
        [.font: settings.editorFont,
         .foregroundColor: theme.primaryText.nsColor,
         .paragraphStyle: paragraphStyle]
    }

    private func reapplyAttributes() {
        let full = NSRange(location: 0, length: textStorage.length)
        guard full.length > 0 else { return }
        textStorage.setAttributes(currentAttributes(), range: full)
    }

    // MARK: Content

    private func loadContent() {
        isLoadingContent = true
        textStorage.setAttributedString(NSAttributedString(string: document.text, attributes: currentAttributes()))
        lineIndex.rebuild(document.text as NSString)
        document.characterCount = characterCount()
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        updateCaretStats()
        ruler.updateThickness(lineCount: lineIndex.lineCount)
        textView.undoManager?.removeAllActions()
        isLoadingContent = false
    }

    /// Pushes live text-view content into the model (before save / tab switch).
    func syncToModel() {
        document.text = textView.string
    }

    var isEmpty: Bool { textStorage.length == 0 }

    func focus() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.scrollView.window else { return }
            window.makeFirstResponder(self.textView)
        }
    }

    /// Ensures the document is scrolled to the top (safety after (re)attach).
    func scrollToTop() {
        textView.scroll(NSPoint.zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func characterCount() -> Int {
        let ns = textView.string as NSString
        if ns.length < 200_000 { return textView.string.count }
        return ns.length
    }

    // MARK: Observers

    private func installObservers() {
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(viewBoundsChanged),
            name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        NotificationCenter.default.addObserver(
            self, selector: #selector(viewBoundsChanged),
            name: NSView.frameDidChangeNotification, object: scrollView)
    }

    @objc private func viewBoundsChanged() {
        ruler.needsDisplay = true
    }

    func teardown() {
        NotificationCenter.default.removeObserver(self)
        textView.delegate = nil
        scrollView.removeFromSuperview()
    }

    // MARK: NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        guard !isLoadingContent else { return }
        document.isDirty = true
        lineIndex.rebuild(textView.string as NSString)
        document.characterCount = characterCount()
        updateCaretStats()
        ruler.updateThickness(lineCount: lineIndex.lineCount)
        ruler.needsDisplay = true
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        updateCaretStats()
        ruler.needsDisplay = true
    }

    private func updateCaretStats() {
        let sel = textView.selectedRange()
        let pos = lineIndex.position(at: min(sel.location, (textView.string as NSString).length))
        document.caretLine = pos.line
        document.caretColumn = pos.column
        document.selectedCount = sel.length > 0 ? (textView.string as NSString).substring(with: sel).count : 0
    }

    // MARK: Find & Replace

    @discardableResult
    func updateSearch(query: String, options: FindOptions, selectFirst: Bool = true) -> FindResult {
        clearHighlights()
        guard !query.isEmpty else { matches = []; currentMatchIndex = -1; return FindResult() }
        matches = computeMatches(query, options)
        guard !matches.isEmpty else { currentMatchIndex = -1; return FindResult() }
        let sel = textView.selectedRange()
        currentMatchIndex = matches.firstIndex { $0.location >= sel.location } ?? 0
        highlightMatches()
        if selectFirst { revealMatch(currentMatchIndex, select: false) }
        return FindResult(current: currentMatchIndex + 1, total: matches.count)
    }

    @discardableResult
    func moveToMatch(forward: Bool) -> FindResult {
        guard !matches.isEmpty else { return FindResult() }
        currentMatchIndex = (currentMatchIndex + (forward ? 1 : -1) + matches.count) % matches.count
        highlightMatches()
        revealMatch(currentMatchIndex, select: true)
        return FindResult(current: currentMatchIndex + 1, total: matches.count)
    }

    @discardableResult
    func replaceCurrent(with replacement: String, query: String, options: FindOptions) -> FindResult {
        guard matches.indices.contains(currentMatchIndex) else { return FindResult(current: 0, total: matches.count) }
        let range = matches[currentMatchIndex]
        if textView.shouldChangeText(in: range, replacementString: replacement) {
            textView.textStorage?.replaceCharacters(in: range, with: replacement)
            textView.didChangeText()
        }
        reapplyAttributes()
        return updateSearch(query: query, options: options)
    }

    @discardableResult
    func replaceAll(query: String, replacement: String, options: FindOptions) -> Int {
        let s = textView.string as NSString
        let found = computeMatches(query, options)
        guard !found.isEmpty else { return 0 }
        let full = NSRange(location: 0, length: s.length)

        let newString: String
        if options.regex {
            let reOpts: NSRegularExpression.Options = options.caseSensitive ? [] : [.caseInsensitive]
            guard let re = try? NSRegularExpression(pattern: query, options: reOpts) else { return 0 }
            newString = re.stringByReplacingMatches(in: textView.string, range: full, withTemplate: replacement)
        } else {
            let mutable = NSMutableString(string: s)
            let opts: NSString.CompareOptions = options.caseSensitive ? [.literal] : [.literal, .caseInsensitive]
            mutable.replaceOccurrences(of: query, with: replacement, options: opts, range: full)
            newString = mutable as String
        }

        if textView.shouldChangeText(in: full, replacementString: newString) {
            textView.textStorage?.replaceCharacters(in: full, with: newString)
            textView.didChangeText()
        }
        reapplyAttributes()
        clearHighlights()
        matches = []
        currentMatchIndex = -1
        return found.count
    }

    func endFind() {
        clearHighlights()
        matches = []
        currentMatchIndex = -1
    }

    private func computeMatches(_ query: String, _ options: FindOptions) -> [NSRange] {
        let s = textView.string as NSString
        guard s.length > 0 else { return [] }
        var result: [NSRange] = []
        if options.regex {
            let reOpts: NSRegularExpression.Options = options.caseSensitive ? [] : [.caseInsensitive]
            guard let re = try? NSRegularExpression(pattern: query, options: reOpts) else { return [] }
            re.enumerateMatches(in: textView.string, range: NSRange(location: 0, length: s.length)) { m, _, _ in
                if let r = m?.range, r.length > 0 { result.append(r) }
            }
        } else {
            let compareOpts: NSString.CompareOptions = options.caseSensitive ? [.literal] : [.literal, .caseInsensitive]
            var searchStart = 0
            while searchStart < s.length {
                let r = s.range(of: query, options: compareOpts,
                                range: NSRange(location: searchStart, length: s.length - searchStart))
                if r.location == NSNotFound { break }
                result.append(r)
                searchStart = r.location + max(1, r.length)
            }
        }
        return result
    }

    private func highlightMatches() {
        guard let lm = textView.layoutManager else { return }
        for (i, r) in matches.enumerated() {
            let color = (i == currentMatchIndex) ? theme.findCurrent.nsColor : theme.findHighlight.nsColor
            lm.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: r)
        }
    }

    private func clearHighlights() {
        guard let lm = textView.layoutManager else { return }
        let full = NSRange(location: 0, length: (textView.string as NSString).length)
        lm.removeTemporaryAttribute(.backgroundColor, forCharacterRange: full)
    }

    private func revealMatch(_ i: Int, select: Bool) {
        guard matches.indices.contains(i) else { return }
        let r = matches[i]
        if select {
            textView.setSelectedRange(r)
        }
        textView.scrollRangeToVisible(r)
        ruler.needsDisplay = true
    }
}
