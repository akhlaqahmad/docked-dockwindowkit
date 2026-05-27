import AppKit
import SwiftUI
import AppCore

/// `NSPanel` subclass that hosts a single floating dock.
///
/// - Non-activating: clicking the panel doesn't steal focus from the active app.
/// - Floats above normal windows (statusBar level) but below screensaver.
/// - Ignores cycling through windows (⌘`).
/// - Joins all spaces and full-screen auxiliary by default.
public final class FloatingDockPanel: NSPanel {

    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.isFloatingPanel = true
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        self.hasShadow = false                              // we render our own shadow if needed
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hidesOnDeactivate = false
        self.ignoresMouseEvents = false
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isReleasedWhenClosed = false
        self.animationBehavior = .utilityWindow
    }
}
