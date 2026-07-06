import AppKit

/// A gutter drawing one line number per logical line (SF Mono), aligned with the
/// text view's line fragments. Wrapped lines show a number only on their first
/// fragment; the trailing empty line is numbered too.
final class LineNumberRulerView: NSRulerView {
    weak var controller: EditorController?

    var font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    var textColor: NSColor = .secondaryLabelColor
    var activeTextColor: NSColor = .labelColor
    var backgroundColor: NSColor = .clear
    var dividerColor: NSColor = .separatorColor

    init(textView: NSTextView, scrollView: NSScrollView) {
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 46
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Widen the gutter to fit the largest line number.
    func updateThickness(lineCount: Int) {
        let digits = max(2, String(lineCount).count)
        let sample = String(repeating: "8", count: digits) as NSString
        let width = sample.size(withAttributes: [.font: font]).width + 18
        let rounded = ceil(width)
        if abs(rounded - ruleThickness) > 0.5 { ruleThickness = rounded }
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = clientView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        backgroundColor.setFill()
        bounds.fill()
        dividerColor.setFill()
        NSRect(x: bounds.maxX - 1, y: bounds.minY, width: 1, height: bounds.height).fill()

        let content = textView.string as NSString
        let insetHeight = textView.textContainerInset.height
        let relativePoint = convert(NSPoint.zero, from: textView)
        let caretLine = controller?.document.caretLine ?? -1

        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: textContainer)
        let firstVisibleChar = layoutManager.characterIndexForGlyph(at: visibleGlyphRange.location)
        var lineNumber = controller?.lineIndex.lineNumber(at: firstVisibleChar) ?? 1

        var glyphIndexForLine = visibleGlyphRange.location
        let visibleEnd = NSMaxRange(visibleGlyphRange)

        while glyphIndexForLine < visibleEnd {
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndexForLine)
            let logicalLineRange = content.lineRange(for: NSRange(location: charIndex, length: 0))
            let glyphRangeForLine = layoutManager.glyphRange(forCharacterRange: logicalLineRange, actualCharacterRange: nil)

            // Draw the number on the first fragment of the logical line only.
            var effectiveRange = NSRange()
            let fragRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndexForLine, effectiveRange: &effectiveRange, withoutAdditionalLayout: true)
            let y = relativePoint.y + fragRect.minY + insetHeight
            drawNumber(lineNumber, atY: y, height: fragRect.height, active: lineNumber == caretLine)

            glyphIndexForLine = NSMaxRange(glyphRangeForLine)
            lineNumber += 1
        }

        // Trailing empty line (buffer ends with a newline, or is empty).
        if layoutManager.extraLineFragmentTextContainer != nil {
            let fragRect = layoutManager.extraLineFragmentRect
            let y = relativePoint.y + fragRect.minY + insetHeight
            drawNumber(lineNumber, atY: y, height: fragRect.height, active: lineNumber == caretLine)
        }
    }

    private func drawNumber(_ n: Int, atY y: CGFloat, height: CGFloat, active: Bool) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: active ? activeTextColor : textColor
        ]
        let str = "\(n)" as NSString
        let size = str.size(withAttributes: attrs)
        let x = ruleThickness - size.width - 9
        let drawY = y + (height - size.height) / 2
        str.draw(at: NSPoint(x: x, y: drawY), withAttributes: attrs)
    }
}
