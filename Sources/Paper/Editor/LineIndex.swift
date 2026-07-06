import Foundation

/// A cache of line-start character offsets, enabling O(log n) line/column lookups
/// for the ruler and status bar instead of rescanning the whole buffer each time.
struct LineIndex {
    private(set) var lineStarts: [Int] = [0]

    var lineCount: Int { lineStarts.count }

    /// Rebuilds the index from the buffer with a single fast character scan.
    mutating func rebuild(_ s: NSString) {
        let len = s.length
        guard len > 0 else { lineStarts = [0]; return }
        var buffer = [unichar](repeating: 0, count: len)
        s.getCharacters(&buffer, range: NSRange(location: 0, length: len))
        var starts = [0]
        starts.reserveCapacity(len / 40 + 1)
        var i = 0
        while i < len {
            if buffer[i] == 0x0A { starts.append(i + 1) }
            i += 1
        }
        lineStarts = starts
    }

    /// 1-based line number containing character `index`.
    func lineNumber(at index: Int) -> Int {
        var lo = 0, hi = lineStarts.count - 1, ans = 0
        while lo <= hi {
            let mid = (lo + hi) / 2
            if lineStarts[mid] <= index { ans = mid; lo = mid + 1 } else { hi = mid - 1 }
        }
        return ans + 1
    }

    /// 1-based (line, column) for a caret at UTF-16 offset `index`.
    func position(at index: Int) -> (line: Int, column: Int) {
        let line = lineNumber(at: index)
        let column = index - lineStarts[line - 1] + 1
        return (line, column)
    }
}
