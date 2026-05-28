import AppKit
import SwiftUI
import AppCore
import DisplayKit

/// Owns a single `FloatingDockPanel` for a single `Dock`. Re-positions when the
/// screen configuration changes; shows/hides when the bound display connects /
/// disconnects; honors `DockBehavior.autoHide` for mouse-driven reveal/hide.
@MainActor
public final class DockWindowController {
    public let dockID: UUID
    private let manager: DockManager
    private let displayObserver: DisplayObserver
    private var panel: FloatingDockPanel?

    // Auto-hide state.
    private var mouseMonitor: Any?
    private var hideTimer: Timer?
    private var isAutoHidden = false
    private var currentAutoHideMode: DockBehavior.AutoHide = .never

    /// Hot-zone padding around the dock for "still considered hovered" calculations.
    /// Slightly larger than zero so the dock doesn't flicker when the cursor
    /// brushes the edge.
    private static let hotZoneInset: CGFloat = 8

    /// Width of the reveal strip at the screen edge in `.always` mode. Mouse
    /// within this many points of the dock's bound edge will summon the panel.
    private static let edgeRevealWidth: CGFloat = 4

    /// Delay before hiding the panel after the cursor leaves the hot zone.
    /// Keeps the dock visible during quick mouse motion across it.
    private static let hideDelaySeconds: TimeInterval = 0.6

    /// Fade durations — keep them snappy (under 200ms) per docs/04-uiux.md §4.7.
    private static let revealDuration: TimeInterval = 0.12
    private static let hideDuration: TimeInterval = 0.18

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

        applyAutoHide(mode: dock.behavior.autoHide)
    }

    public func hide() {
        teardownAutoHide()
        panel?.orderOut(nil)
        isAutoHidden = false
    }

    public func close() {
        teardownAutoHide()
        panel?.close()
        panel = nil
    }

    // MARK: - Auto-hide

    /// Apply the auto-hide mode declared by `DockBehavior`. Idempotent — re-call
    /// any time the mode might have changed (e.g., from the Inspector).
    public func applyAutoHide(mode: DockBehavior.AutoHide) {
        guard currentAutoHideMode != mode || mouseMonitor == nil else { return }
        teardownAutoHide()
        currentAutoHideMode = mode

        switch mode {
        case .never:
            // Always visible — reset alpha and bail.
            setPanelAlpha(1.0, animated: false)
            isAutoHidden = false

        case .onMouseLeave:
            // Start visible. Hide when cursor leaves the hot zone; reveal when it returns.
            setPanelAlpha(1.0, animated: false)
            isAutoHidden = false
            startMouseMonitor()
            evaluate()

        case .always:
            // Start hidden. Reveal only when cursor enters hot zone or edge-reveal strip.
            setPanelAlpha(0.0, animated: false)
            isAutoHidden = true
            startMouseMonitor()
            evaluate()

        case .onFullscreen:
            // V1.1 — requires NSWorkspace.didActivateApplicationNotification +
            // active app's `isFullScreen`. Treat as `.never` for now.
            setPanelAlpha(1.0, animated: false)
            isAutoHidden = false
        }
    }

    private func startMouseMonitor() {
        guard mouseMonitor == nil else { return }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            // Global monitors fire on a background-ish context; bounce to main.
            Task { @MainActor [weak self] in
                self?.evaluate()
            }
        }
    }

    private func teardownAutoHide() {
        if let m = mouseMonitor { NSEvent.removeMonitor(m) }
        mouseMonitor = nil
        hideTimer?.invalidate()
        hideTimer = nil
    }

    /// Decide whether the panel should be visible based on cursor position.
    /// Idempotent; safe to call at any rate.
    private func evaluate() {
        guard let panel else { return }
        let cursor = NSEvent.mouseLocation
        let frame = panel.frame
        let hot = frame.insetBy(dx: -Self.hotZoneInset, dy: -Self.hotZoneInset)

        let wantsVisible: Bool
        if hot.contains(cursor) {
            wantsVisible = true
        } else if currentAutoHideMode == .always,
                  let dock = manager.library.docks.first(where: { $0.id == dockID }),
                  let screen = displayObserver.screen(for: dock.screenID) ?? NSScreen.main,
                  isCursorInEdgeRevealZone(cursor, dock: dock, screen: screen) {
            wantsVisible = true
        } else {
            wantsVisible = false
        }

        if wantsVisible {
            revealPanel()
        } else {
            scheduleHide()
        }
    }

    /// True when the cursor is within `edgeRevealWidth` of the screen edge that
    /// the dock is pinned to (so mousing into the corner reveals it).
    private func isCursorInEdgeRevealZone(_ cursor: NSPoint, dock: Dock, screen: NSScreen) -> Bool {
        let visible = screen.visibleFrame
        let w = Self.edgeRevealWidth
        switch dock.position.edge {
        case .bottom:   return cursor.y <= visible.minY + w
        case .top:      return cursor.y >= visible.maxY - w
        case .leading:  return cursor.x <= visible.minX + w
        case .trailing: return cursor.x >= visible.maxX - w
        case .floating: return false
        }
    }

    private func revealPanel() {
        hideTimer?.invalidate(); hideTimer = nil
        guard isAutoHidden else { return }
        isAutoHidden = false
        setPanelAlpha(1.0, animated: true, duration: Self.revealDuration)
    }

    private func scheduleHide() {
        guard !isAutoHidden, hideTimer == nil else { return }
        hideTimer = Timer.scheduledTimer(withTimeInterval: Self.hideDelaySeconds, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performScheduledHide()
            }
        }
    }

    private func performScheduledHide() {
        hideTimer = nil
        guard !isAutoHidden else { return }
        isAutoHidden = true
        setPanelAlpha(0.0, animated: true, duration: Self.hideDuration)
    }

    private func setPanelAlpha(_ value: CGFloat, animated: Bool, duration: TimeInterval = 0.15) {
        guard let panel else { return }
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = duration
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = value
            }
        } else {
            panel.alphaValue = value
        }
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
