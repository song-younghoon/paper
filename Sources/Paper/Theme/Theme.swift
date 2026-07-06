import SwiftUI
import AppKit

/// A complete set of semantic color tokens. The three built-in presets are the
/// "비주얼 톤 3종" from the design; the accent is user-overridable.
struct Theme: Identifiable, Equatable {
    let id: String
    let name: String
    let isDark: Bool

    // Surfaces
    var windowBackground: PaperColor
    var toolbarBackground: PaperColor
    var sidebarBackground: PaperColor
    var editorBackground: PaperColor
    var statusBarBackground: PaperColor
    var elevatedBackground: PaperColor   // palettes, popovers
    var controlBackground: PaperColor    // search fields, inset controls

    // Text
    var primaryText: PaperColor
    var secondaryText: PaperColor
    var tertiaryText: PaperColor

    // Editor specifics
    var lineNumber: PaperColor
    var lineNumberActive: PaperColor
    var currentLine: PaperColor

    // Accents & highlights
    var accent: PaperColor
    var selection: PaperColor
    var sidebarSelection: PaperColor
    var findHighlight: PaperColor
    var findCurrent: PaperColor

    // Lines
    var divider: PaperColor

    /// Foreground that reads well on top of the accent (for filled buttons).
    var onAccent: PaperColor {
        accent.luminance > 0.5 ? PaperColor(hex: 0x1D1D1F) : PaperColor(hex: 0xFFFFFF)
    }

    var appearance: NSAppearance? {
        NSAppearance(named: isDark ? .darkAqua : .aqua)
    }

    var colorScheme: ColorScheme { isDark ? .dark : .light }

    /// Returns a copy whose accent (and accent-derived highlights) use `custom`.
    func withAccent(_ custom: PaperColor) -> Theme {
        var t = self
        t.accent = custom
        t.selection = custom.opacity(isDark ? 0.32 : 0.28)
        t.sidebarSelection = custom.opacity(isDark ? 0.26 : 0.16)
        return t
    }

    static func == (lhs: Theme, rhs: Theme) -> Bool {
        lhs.id == rhs.id && lhs.accent == rhs.accent && lhs.selection == rhs.selection
    }
}

// MARK: - Built-in presets

extension Theme {
    /// 1a — Light · 웜 페이퍼 톤. Paper-like background, calm amber accent.
    static let warmPaper = Theme(
        id: "warm-paper",
        name: "웜 페이퍼",
        isDark: false,
        windowBackground:   PaperColor(hex: 0xE9E3D8),
        toolbarBackground:  PaperColor(hex: 0xEAE4DA),
        sidebarBackground:  PaperColor(hex: 0xEDE7DC),
        editorBackground:   PaperColor(hex: 0xF7F2EA),
        statusBarBackground:PaperColor(hex: 0xEAE4DA),
        elevatedBackground: PaperColor(hex: 0xF5F0E7),
        controlBackground:  PaperColor(hex: 0xE3DCCE),
        primaryText:        PaperColor(hex: 0x2C2822),
        secondaryText:      PaperColor(hex: 0x877E6E),
        tertiaryText:       PaperColor(hex: 0xA89E8C),
        lineNumber:         PaperColor(hex: 0xC0B7A4),
        lineNumberActive:   PaperColor(hex: 0x6E6555),
        currentLine:        PaperColor(hex: 0x5A4A28, alpha: 0.06),
        accent:             PaperColor(hex: 0xB77F33),
        selection:          PaperColor(hex: 0xB77F33, alpha: 0.26),
        sidebarSelection:   PaperColor(hex: 0xB77F33, alpha: 0.16),
        findHighlight:      PaperColor(hex: 0xF0DE87, alpha: 0.75),
        findCurrent:        PaperColor(hex: 0xF3B948),
        divider:            PaperColor(hex: 0xDBD3C3)
    )

    /// 1b — Light · 쿨 시스템 톤. Pure white editor, macOS blue accent.
    static let coolSystem = Theme(
        id: "cool-system",
        name: "쿨 시스템",
        isDark: false,
        windowBackground:   PaperColor(hex: 0xECECEE),
        toolbarBackground:  PaperColor(hex: 0xEAEAEC),
        sidebarBackground:  PaperColor(hex: 0xE8E8EB),
        editorBackground:   PaperColor(hex: 0xFFFFFF),
        statusBarBackground:PaperColor(hex: 0xECECEE),
        elevatedBackground: PaperColor(hex: 0xFBFBFD),
        controlBackground:  PaperColor(hex: 0xE4E4E8),
        primaryText:        PaperColor(hex: 0x1D1D1F),
        secondaryText:      PaperColor(hex: 0x7D7D82),
        tertiaryText:       PaperColor(hex: 0xADADB2),
        lineNumber:         PaperColor(hex: 0xC2C2C7),
        lineNumberActive:   PaperColor(hex: 0x6E6E73),
        currentLine:        PaperColor(hex: 0x000000, alpha: 0.035),
        accent:             PaperColor(hex: 0x0A84FF),
        selection:          PaperColor(hex: 0xB3D7FF, alpha: 0.9),
        sidebarSelection:   PaperColor(hex: 0x0A84FF, alpha: 0.14),
        findHighlight:      PaperColor(hex: 0xFFE9A8),
        findCurrent:        PaperColor(hex: 0xFFC24B),
        divider:            PaperColor(hex: 0xDCDCE0)
    )

    /// 1c — Dark · 그레파이트 톤.
    static let darkGraphite = Theme(
        id: "dark-graphite",
        name: "다크 그레파이트",
        isDark: true,
        windowBackground:   PaperColor(hex: 0x232326),
        toolbarBackground:  PaperColor(hex: 0x202023),
        sidebarBackground:  PaperColor(hex: 0x1E1E21),
        editorBackground:   PaperColor(hex: 0x151517),
        statusBarBackground:PaperColor(hex: 0x202023),
        elevatedBackground: PaperColor(hex: 0x2C2C31),
        controlBackground:  PaperColor(hex: 0x2A2A2E),
        primaryText:        PaperColor(hex: 0xE7E7EA),
        secondaryText:      PaperColor(hex: 0x98989F),
        tertiaryText:       PaperColor(hex: 0x69696F),
        lineNumber:         PaperColor(hex: 0x4C4C52),
        lineNumberActive:   PaperColor(hex: 0x9A9AA0),
        currentLine:        PaperColor(hex: 0xFFFFFF, alpha: 0.045),
        accent:             PaperColor(hex: 0x0A84FF),
        selection:          PaperColor(hex: 0x3B6EA5, alpha: 0.45),
        sidebarSelection:   PaperColor(hex: 0xFFFFFF, alpha: 0.08),
        findHighlight:      PaperColor(hex: 0x6B5A1E),
        findCurrent:        PaperColor(hex: 0xB8862B),
        divider:            PaperColor(hex: 0x313135)
    )

    static let allPresets: [Theme] = [.warmPaper, .coolSystem, .darkGraphite]

    static func preset(id: String) -> Theme {
        allPresets.first { $0.id == id } ?? .warmPaper
    }
}

/// A few accent swatches offered in settings alongside the free color well.
struct AccentSwatch: Identifiable {
    let id: String
    let name: String
    let color: PaperColor
    static let presets: [AccentSwatch] = [
        .init(id: "amber",   name: "앰버",   color: PaperColor(hex: 0xB77F33)),
        .init(id: "blue",    name: "블루",   color: PaperColor(hex: 0x0A84FF)),
        .init(id: "graphite",name: "그래파이트", color: PaperColor(hex: 0x636369)),
        .init(id: "red",     name: "레드",   color: PaperColor(hex: 0xE0453A)),
        .init(id: "green",   name: "그린",   color: PaperColor(hex: 0x34A853)),
        .init(id: "purple",  name: "퍼플",   color: PaperColor(hex: 0x8E5CD9)),
        .init(id: "pink",    name: "핑크",   color: PaperColor(hex: 0xE5589B)),
        .init(id: "teal",    name: "틸",     color: PaperColor(hex: 0x1AA5A5)),
    ]
}
