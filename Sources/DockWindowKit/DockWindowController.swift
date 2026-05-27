import AppKit
import SwiftUI
import AppCore
import DisplayKit

/// Owns a single `FloatingDockPanel` for a single `Dock`. Re-positions when the screen
/// configuration changes; shows/hides when the bound display connects/disconnects.
@MainActor
public final class DockWindowController {
    public let dockID: UUID
    private let manager: DockManager
    private let displayObserver: DisplayObserver
    private var panel: FloatingDockPanel?

    public init(dockID: UUID, manager: DockManager, displayObserver: DisplayObserver) {
        self.dockID = dockID
        self.manager = manager
        self.displayObserver = displayObserver
    }

    public func show() {
        guard let dock = manager.library.docks.first(where: { $0.id == dockID }) else { return }
        guard dock.isEnabled else { hide(); return }

        let screen = displayObserver.screen(for: dock.screenID) ?? NSScreen.main
        guard let screen else { hide(); return }

        let panel = panel ?? FloatingDockPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 80))
        if self.panel == nil { self.panel = panel }

        panel.contentView = NSHostingView(
            rootView: DockHostView(dockID: dockID, manager: manager)
        )

        let frame = Self.computeFrame(for: dock, on: screen, panelSize: panel.frame.size)
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    public func hide() {
        panel?.orderOut(nil)
    }

    public func close() {
        panel?.close()
        panel = nil
    }

    // MARK: - Geometry

    public static func computeFrame(for dock: Dock, on screen: NSScreen, panelSize: CGSize) -> NSRect {
        let visible = screen.visibleFrame
        let margin: CGFloat = 16
        let size = panelSize

        let x: CGFloat
        let y: CGFloat

        switch dock.position.edge {
        case .bottom:
            x = visible.midX - size.width / 2 + dock.position.offset.x
            y = visible.minY + margin + dock.position.offset.y
        case .top:
            x = visible.midX - size.width / 2 + dock.position.offset.x
            y = visible.maxY - size.height - margin + dock.position.offset.y
        case .leading:
            x = visible.minX + margin + dock.position.offset.x
            y = visible.midY - size.height / 2 + dock.position.offset.y
        case .trailing:
            x = visible.maxX - size.width - margin + dock.position.offset.x
            y = visible.midY - size.height / 2 + dock.position.offset.y
        case .floating:
            x = visible.minX + dock.position.offset.x
            y = visible.minY + dock.position.offset.y
        }

        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }
}
