import AppKit

/// Tracks the OS light/dark appearance and mirrors it into `AppSettings`, so the
/// `.systemAuto` theme follows the system. We never set `NSApp.appearance`
/// (only per-window), so this reflects the real OS setting without feedback.
@MainActor
final class AppearanceObserver {
    private var observation: NSKeyValueObservation?

    init(settings: AppSettings) {
        settings.systemIsDark = Self.isDark(NSApp.effectiveAppearance)
        observation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak settings] _, _ in
            Task { @MainActor in
                settings?.systemIsDark = Self.isDark(NSApp.effectiveAppearance)
            }
        }
    }

    nonisolated static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}
