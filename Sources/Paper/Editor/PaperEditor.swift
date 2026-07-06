import SwiftUI
import AppKit

/// Hosts the active document's live editor. A single container view is reused
/// across tab switches; only the child scroll view is swapped, so each tab keeps
/// its undo stack, scroll offset, and selection.
struct PaperEditor: NSViewRepresentable {
    @Environment(AppState.self) private var app
    let document: TextDocument
    let theme: Theme

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        let controller = app.controller(for: document)
        controller.applyThemeIfNeeded(theme)
        controller.applySettingsIfNeeded()

        if controller.scrollView.superview !== container {
            container.subviews.forEach { $0.removeFromSuperview() }
            let scroll = controller.scrollView
            scroll.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(scroll)
            NSLayoutConstraint.activate([
                scroll.topAnchor.constraint(equalTo: container.topAnchor),
                scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ])
            controller.focus()
            DispatchQueue.main.async { controller.scrollToTop() }
        }
    }
}
