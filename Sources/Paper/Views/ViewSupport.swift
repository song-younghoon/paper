import SwiftUI
import AppKit

// MARK: - Theme in the environment

private struct PaperThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .warmPaper
}

extension EnvironmentValues {
    var paperTheme: Theme {
        get { self[PaperThemeKey.self] }
        set { self[PaperThemeKey.self] = newValue }
    }
}

// MARK: - Window configuration

/// Applies the theme's appearance and background to the host `NSWindow` so native
/// chrome (scrollers, sheets) matches, and hides the title so our custom top bar
/// owns the titlebar region.
/// Shared layout metrics so the SwiftUI top bar and the native traffic-light
/// alignment agree on the titlebar height.
enum PaperMetrics {
    static let topBarHeight: CGFloat = 46
}

struct WindowConfigurator: NSViewRepresentable {
    let isDark: Bool
    let background: NSColor

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(view.window)
            context.coordinator.attach(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(nsView.window)
            context.coordinator.attach(to: nsView.window)
        }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.styleMask.insert(.fullSizeContentView)
        window.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        window.backgroundColor = background
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = false
    }

    /// Keeps the traffic-light buttons vertically centered in our custom top bar,
    /// re-applying whenever AppKit relays them out (resize, key changes, etc.).
    final class Coordinator: NSObject {
        private weak var window: NSWindow?

        func attach(to window: NSWindow?) {
            guard let window else { return }
            if window !== self.window {
                self.window = window
                let nc = NotificationCenter.default
                for name in [NSWindow.didResizeNotification,
                             NSWindow.didBecomeKeyNotification,
                             NSWindow.didResignKeyNotification,
                             NSWindow.didEnterFullScreenNotification,
                             NSWindow.didExitFullScreenNotification] {
                    nc.addObserver(self, selector: #selector(reposition), name: name, object: window)
                }
            }
            reposition()
            // Nudge after initial layout settles.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in self?.reposition() }
        }

        @objc private func reposition() {
            guard let window,
                  let close = window.standardWindowButton(.closeButton),
                  let superview = close.superview else { return }
            let buttons = [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton]
                .compactMap { window.standardWindowButton($0) }
            let buttonHeight = close.frame.height
            // Position each button's top `topFromTop` points below the window's top edge.
            let topFromTop = (PaperMetrics.topBarHeight - buttonHeight) / 2
            for button in buttons {
                let newY = superview.bounds.height - topFromTop - button.frame.height
                if abs(button.frame.origin.y - newY) > 0.5 {
                    button.setFrameOrigin(NSPoint(x: button.frame.origin.x, y: newY))
                }
            }
        }
    }
}

/// A draggable divider between the sidebar and editor. Shows a horizontal-resize
/// cursor on hover and updates the sidebar width live while dragging.
struct SidebarResizeHandle: View {
    @Environment(AppState.self) private var app
    @Environment(\.paperTheme) private var theme
    @State private var dragStartWidth: Double?

    var body: some View {
        Rectangle()
            .fill(theme.divider.color)
            .frame(width: 1)
            .frame(maxHeight: .infinity)
            .overlay {
                Color.clear
                    .frame(width: 11)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active: NSCursor.resizeLeftRight.set()
                        case .ended: NSCursor.arrow.set()
                        @unknown default: break
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                let base = dragStartWidth ?? app.sidebarWidth
                                if dragStartWidth == nil { dragStartWidth = base }
                                app.setSidebarWidth(base + value.translation.width)
                            }
                            .onEnded { _ in
                                dragStartWidth = nil
                                app.persistSidebarWidth()
                            }
                    )
            }
    }
}

/// A transparent region that drags the window on click — used behind the top bar.
struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
        override func mouseDragged(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

// MARK: - Reusable controls

/// A borderless SF Symbol button with a subtle hover background — the toolbar idiom.
struct IconButton: View {
    let systemName: String
    var size: CGFloat = 13
    var help: String = ""
    let action: () -> Void

    @Environment(\.paperTheme) private var theme
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(theme.secondaryText.color)
                .frame(width: 26, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(theme.primaryText.color.opacity(hovering ? 0.08 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

/// The "⌘K" pill in the top-right that opens the command palette.
struct KeyHintPill: View {
    let text: String
    var active = false
    @Environment(\.paperTheme) private var theme
    @State private var hovering = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(theme.secondaryText.color)
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(theme.primaryText.color.opacity(hovering ? 0.10 : 0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(theme.divider.color, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// Small keyboard-shortcut chips shown in palettes (e.g. ⌘S).
struct ShortcutChips: View {
    let keys: [String]
    @Environment(\.paperTheme) private var theme
    var body: some View {
        HStack(spacing: 3) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.secondaryText.color)
                    .frame(minWidth: 18, minHeight: 18)
                    .padding(.horizontal, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(theme.primaryText.color.opacity(0.07))
                    )
            }
        }
    }
}

extension View {
    /// Fills available space and aligns content, a common layout shorthand.
    func expand(_ alignment: Alignment = .center) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
}

// MARK: - Palette scaffold

/// The dimmed backdrop + centered elevated card shared by the ⌘K and ⌘P palettes.
struct PaletteScaffold<Content: View>: View {
    var width: CGFloat = 580
    let onBackgroundTap: () -> Void
    @ViewBuilder var content: Content
    @Environment(\.paperTheme) private var theme

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.12)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onBackgroundTap)
            content
                .frame(width: width)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme.elevatedBackground.color)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(theme.divider.color, lineWidth: 1)
                )
                .shadow(color: .black.opacity(theme.isDark ? 0.5 : 0.22), radius: 30, y: 14)
                .padding(.top, 92)
        }
    }
}

/// Footer hint row for palettes (e.g. "↑↓ 이동   ↵ 실행   esc 닫기").
struct PaletteFooter: View {
    let hints: [(String, String)]
    @Environment(\.paperTheme) private var theme
    var body: some View {
        HStack(spacing: 14) {
            ForEach(hints, id: \.0) { key, label in
                HStack(spacing: 5) {
                    Text(key)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.secondaryText.color)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 4).fill(theme.primaryText.color.opacity(0.07)))
                    Text(label)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.tertiaryText.color)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

/// Installs an app-local key monitor while a palette is visible, so arrow/enter/
/// escape navigation works regardless of which subview holds focus.
struct PaletteKeyMonitor: ViewModifier {
    let onUp: () -> Void
    let onDown: () -> Void
    let onSelect: (_ commandModifier: Bool) -> Void
    let onClose: () -> Void

    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    switch event.keyCode {
                    case 126: onUp(); return nil       // up arrow
                    case 125: onDown(); return nil      // down arrow
                    case 36, 76:                         // return / keypad enter
                        onSelect(event.modifierFlags.contains(.command)); return nil
                    case 53: onClose(); return nil       // escape
                    default: return event
                    }
                }
            }
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
            }
    }
}

extension View {
    func paletteKeyMonitor(onUp: @escaping () -> Void,
                           onDown: @escaping () -> Void,
                           onSelect: @escaping (Bool) -> Void,
                           onClose: @escaping () -> Void) -> some View {
        modifier(PaletteKeyMonitor(onUp: onUp, onDown: onDown, onSelect: onSelect, onClose: onClose))
    }
}
