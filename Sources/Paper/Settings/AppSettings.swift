import SwiftUI
import AppKit
import Observation

/// Which visual tone is active. The three built-ins plus a system-following mode.
enum ThemeSelection: String, CaseIterable, Identifiable, Sendable {
    case warmPaper    = "warm-paper"
    case coolSystem   = "cool-system"
    case darkGraphite = "dark-graphite"
    case systemAuto   = "system-auto"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .warmPaper:    return "웜 페이퍼"
        case .coolSystem:   return "쿨 시스템"
        case .darkGraphite: return "다크 그레파이트"
        case .systemAuto:   return "시스템 자동"
        }
    }

    var subtitle: String {
        switch self {
        case .warmPaper:    return "종이 같은 라이트"
        case .coolSystem:   return "순백 라이트"
        case .darkGraphite: return "그레파이트 다크"
        case .systemAuto:   return "시스템 설정 따름"
        }
    }
}

/// Persisted, observable application preferences. Backed by `UserDefaults`.
@MainActor
@Observable
final class AppSettings {

    static let defaultFontSize: Double = 14
    static let minFontSize: Double = 8
    static let maxFontSize: Double = 40

    // MARK: Editor
    var fontName: String = ""              // "" = system font
    var fontSize: Double = defaultFontSize
    var showLineNumbers: Bool = true
    var lineWrap: Bool = true
    var autoSaveEnabled: Bool = true
    var autoSaveInterval: Int = 10         // seconds
    var tabWidth: Int = 4

    // MARK: File
    var defaultEncodingID: String = "utf8"
    var defaultLineEnding: LineEnding = .lf

    // MARK: Appearance
    var themeSelection: ThemeSelection = .warmPaper
    var useCustomAccent: Bool = false
    var customAccent: PaperColor = PaperColor(hex: 0xB77F33)

    /// Tracks the OS light/dark state for `.systemAuto`. Updated by `AppearanceObserver`.
    var systemIsDark: Bool = false

    // MARK: Derived

    var defaultEncoding: TextEncoding { TextEncoding.byID(defaultEncodingID) }

    /// The fully-resolved theme, applying the custom accent when enabled.
    var activeTheme: Theme {
        let base: Theme
        switch themeSelection {
        case .warmPaper:    base = .warmPaper
        case .coolSystem:   base = .coolSystem
        case .darkGraphite: base = .darkGraphite
        case .systemAuto:   base = systemIsDark ? .darkGraphite : .coolSystem
        }
        return useCustomAccent ? base.withAccent(customAccent) : base
    }

    /// The body font for the editor.
    var editorFont: NSFont {
        let size = CGFloat(fontSize)
        if fontName.isEmpty {
            return NSFont.systemFont(ofSize: size)
        }
        if fontName == "SF Mono" {
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
        return NSFont(name: fontName, size: size) ?? NSFont.systemFont(ofSize: size)
    }

    /// The monospaced font used for the line-number ruler (SF Mono).
    var lineNumberFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize) * 0.86, weight: .regular)
    }

    // MARK: Persistence

    @ObservationIgnored private var isLoading = false
    @ObservationIgnored private let defaults = UserDefaults.standard

    init() {
        load()
        beginObserving()
    }

    /// Re-arming observation loop: persists whenever any tracked property changes.
    private func beginObserving() {
        withObservationTracking {
            _ = fontName; _ = fontSize; _ = showLineNumbers; _ = lineWrap
            _ = autoSaveEnabled; _ = autoSaveInterval; _ = tabWidth
            _ = defaultEncodingID; _ = defaultLineEnding
            _ = themeSelection; _ = useCustomAccent; _ = customAccent
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.persist()
                self.beginObserving()
            }
        }
    }

    private enum Key {
        static let fontName = "fontName"
        static let fontSize = "fontSize"
        static let showLineNumbers = "showLineNumbers"
        static let lineWrap = "lineWrap"
        static let autoSaveEnabled = "autoSaveEnabled"
        static let autoSaveInterval = "autoSaveInterval"
        static let tabWidth = "tabWidth"
        static let defaultEncodingID = "defaultEncodingID"
        static let defaultLineEnding = "defaultLineEnding"
        static let themeSelection = "themeSelection"
        static let useCustomAccent = "useCustomAccent"
        static let accentHex = "customAccentHex"
    }

    private func load() {
        isLoading = true
        defer { isLoading = false }

        if defaults.object(forKey: Key.fontSize) == nil {
            // First launch — nothing to load, keep defaults.
            return
        }
        fontName = defaults.string(forKey: Key.fontName) ?? ""
        fontSize = defaults.double(forKey: Key.fontSize)
        showLineNumbers = defaults.bool(forKey: Key.showLineNumbers)
        lineWrap = defaults.bool(forKey: Key.lineWrap)
        autoSaveEnabled = defaults.bool(forKey: Key.autoSaveEnabled)
        autoSaveInterval = max(2, defaults.integer(forKey: Key.autoSaveInterval))
        tabWidth = [2, 4, 8].contains(defaults.integer(forKey: Key.tabWidth)) ? defaults.integer(forKey: Key.tabWidth) : 4
        defaultEncodingID = defaults.string(forKey: Key.defaultEncodingID) ?? "utf8"
        defaultLineEnding = LineEnding(rawValue: defaults.string(forKey: Key.defaultLineEnding) ?? "lf") ?? .lf
        themeSelection = ThemeSelection(rawValue: defaults.string(forKey: Key.themeSelection) ?? "warm-paper") ?? .warmPaper
        useCustomAccent = defaults.bool(forKey: Key.useCustomAccent)
        let hex = defaults.object(forKey: Key.accentHex) as? Int ?? 0xB77F33
        customAccent = PaperColor(hex: UInt32(hex))
    }

    /// Writes all preferences back to `UserDefaults`. Called after any change.
    func persist() {
        guard !isLoading else { return }
        defaults.set(fontName, forKey: Key.fontName)
        defaults.set(fontSize, forKey: Key.fontSize)
        defaults.set(showLineNumbers, forKey: Key.showLineNumbers)
        defaults.set(lineWrap, forKey: Key.lineWrap)
        defaults.set(autoSaveEnabled, forKey: Key.autoSaveEnabled)
        defaults.set(autoSaveInterval, forKey: Key.autoSaveInterval)
        defaults.set(tabWidth, forKey: Key.tabWidth)
        defaults.set(defaultEncodingID, forKey: Key.defaultEncodingID)
        defaults.set(defaultLineEnding.rawValue, forKey: Key.defaultLineEnding)
        defaults.set(themeSelection.rawValue, forKey: Key.themeSelection)
        defaults.set(useCustomAccent, forKey: Key.useCustomAccent)
        let hex = (Int(customAccent.r * 255) << 16) | (Int(customAccent.g * 255) << 8) | Int(customAccent.b * 255)
        defaults.set(hex, forKey: Key.accentHex)
    }
}
