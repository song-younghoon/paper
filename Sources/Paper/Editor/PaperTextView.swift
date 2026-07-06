import AppKit

/// The plain-text `NSTextView`. It owns background drawing so it can paint a
/// subtle current-line highlight beneath the text (and the theme background
/// beyond the last glyph).
final class PaperTextView: NSTextView {
    var editorBackgroundColor: NSColor = .textBackgroundColor { didSet { needsDisplay = true } }
    var currentLineColor: NSColor = .clear
    var highlightsCurrentLine = true

    /// Called when files are dropped onto the editor. Returns true if handled
    /// (so they open as tabs instead of being inserted as text).
    var onOpenFiles: (([URL]) -> Bool)?

    override var acceptsFirstResponder: Bool { true }

    // MARK: File drop → open (instead of inserting the path)

    private func droppedFileURLs(_ sender: NSDraggingInfo) -> [URL]? {
        let opts: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: opts) as? [URL],
              !urls.isEmpty else { return nil }
        return urls
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedFileURLs(sender) != nil ? .copy : super.draggingEntered(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedFileURLs(sender) != nil ? .copy : super.draggingUpdated(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let urls = droppedFileURLs(sender), let handler = onOpenFiles, handler(urls) {
            return true
        }
        return super.performDragOperation(sender)
    }

    // We paint our own background (drawsBackground is off) to layer the
    // current-line highlight correctly.
    override func draw(_ dirtyRect: NSRect) {
        editorBackgroundColor.setFill()
        dirtyRect.fill()
        drawCurrentLineHighlight()
        super.draw(dirtyRect)
    }

    private func drawCurrentLineHighlight() {
        guard highlightsCurrentLine,
              currentLineColor.alphaComponent > 0,
              let layoutManager, textContainer != nil,
              selectedRange().length == 0 else { return }

        let nsLength = (string as NSString).length
        let charIndex = min(selectedRange().location, nsLength)
        let fragRect: NSRect

        if layoutManager.numberOfGlyphs == 0 {
            fragRect = layoutManager.extraLineFragmentRect
        } else if charIndex >= nsLength, layoutManager.extraLineFragmentTextContainer != nil {
            fragRect = layoutManager.extraLineFragmentRect
        } else {
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: min(charIndex, nsLength - 1))
            fragRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
        }

        guard fragRect.height > 0 else { return }
        let inset = textContainerInset
        let rect = NSRect(x: 0, y: fragRect.minY + inset.height, width: bounds.width, height: fragRect.height)
        currentLineColor.setFill()
        rect.fill()
    }

    // Keep the caret highlight fresh as it moves.
    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        if highlightsCurrentLine { needsDisplay = true }
    }
}
