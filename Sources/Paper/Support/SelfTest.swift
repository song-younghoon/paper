import Foundation

/// Runs the core (non-UI) engine through assertions and prints a report. Invoked
/// with `Paper --selftest`, so it exercises the exact production code paths.
enum SelfTest {
    static func run() -> Int32 {
        var passed = 0, failed = 0
        func check(_ name: String, _ condition: Bool) {
            if condition { passed += 1; print("  ✓ \(name)") }
            else { failed += 1; print("  ✗ \(name)") }
        }

        print("Paper self-test")

        // Encoding: EUC-KR must be a real codec, round-tripping Korean.
        let korean = "안녕하세요, Paper 편집기입니다."
        if let euc = korean.data(using: .eucKR), let back = String(data: euc, encoding: .eucKR) {
            check("EUC-KR round trip", back == korean)
        } else {
            check("EUC-KR round trip", false)
        }

        // FileCodec should detect EUC-KR when UTF-8 fails.
        if let eucData = "한국어 인코딩".data(using: .eucKR) {
            let decoded = FileCodec.decode(eucData, preferred: .utf8)
            check("EUC-KR auto-detect", decoded.encoding.id == "euckr" && decoded.text == "한국어 인코딩")
        } else {
            check("EUC-KR auto-detect", false)
        }

        // UTF-8 with BOM.
        var bomData = Data([0xEF, 0xBB, 0xBF])
        bomData.append("헬로".data(using: .utf8)!)
        let bomDecoded = FileCodec.decode(bomData, preferred: .utf8)
        check("UTF-8 BOM detect", bomDecoded.encoding.id == "utf8bom" && bomDecoded.text == "헬로")

        // UTF-8 encode with CRLF line ending.
        if let out = FileCodec.encode("a\nb", encoding: .utf8, lineEnding: .crlf) {
            check("Encode CRLF", out == "a\r\nb".data(using: .utf8))
        } else {
            check("Encode CRLF", false)
        }

        // Line-ending detection.
        check("Detect CRLF", LineEnding.detect(in: "x\r\ny\r\nz") == .crlf)
        check("Detect LF", LineEnding.detect(in: "x\ny\nz") == .lf)
        check("Detect CR", LineEnding.detect(in: "x\ry\rz") == .cr)
        check("Normalize to CRLF", LineEnding.crlf.normalize("a\nb\r\nc\rd") == "a\r\nb\r\nc\r\nd")

        // LineIndex line/column math.
        var idx = LineIndex()
        idx.rebuild("abc\nde\nf" as NSString)   // starts: [0,4,7]
        check("LineIndex count", idx.lineCount == 3)
        let p0 = idx.position(at: 0); check("LineIndex pos(0)", p0.line == 1 && p0.column == 1)
        let p5 = idx.position(at: 5); check("LineIndex pos(5)", p5.line == 2 && p5.column == 2)
        let p7 = idx.position(at: 7); check("LineIndex pos(7)", p7.line == 3 && p7.column == 1)

        // Fuzzy matching.
        check("Fuzzy substring", fuzzyScore("저장", "저장하기") != nil)
        check("Fuzzy subsequence", fuzzyScore("svl", "save all") != nil)
        check("Fuzzy no match", fuzzyScore("zzz", "save") == nil)

        // Document naming.
        let doc = TextDocument(untitledNumber: 3)
        check("Untitled name", doc.displayName == "제목 없음 3")

        print("\(passed) passed, \(failed) failed")
        return failed == 0 ? 0 : 1
    }
}
