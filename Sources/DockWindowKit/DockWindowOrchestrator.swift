import AppKit
import AppCore
import DisplayKit
import Observation

/// Watches the library + display configuration and ensures one
/// `DockWindowController` exists per dock, showing/hiding as appropriate.
@MainActor
public final class DockWindowOrchestrator {
    private let manager: DockManager
    private let displayObserver: DisplayObserver
    private var controllers: [UUID: DockWindowController] = [:]
    private var observation: Task<Void, Never>?

    public init(manager: DockManager, displayObserver: DisplayObserver) {
        self.manager = manager
        self.displayObserver = displayObserver
    }

    public func start() {
        displayObserver.start()
        displayObserver.onChange = { [weak self] in
            Task { @MainActor in self?.reconcile() }
        }
        reconcile()
        observeLibrary()
    }

    public func stop() {
        observation?.cancel()
        observation = nil
        for (_, controller) in controllers { controller.close() }
        controllers.removeAll()
        displayObserver.stop()
    }

    /// Re-arm `withObservationTracking` so any change to docks (added /
    /// removed / `isEnabled` flipped / `behavior.autoHide` changed) triggers a
    /// reconcile. `withObservationTracking` fires exactly once per registered
    /// read set, so we re-call it after every change to keep watching.
    private func observeLibrary() {
        withObservationTracking { [weak self] in
            guard let self else { return }
            // Read every field we care about so the tracker registers them.
            for dock in self.manager.library.docks {
                _ = dock.id
                _ = dock.isEnabled
                _ = dock.behavior.autoHide
                _ = dock.position
                _ = dock.screenID
            }
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.reconcile()
                self?.observeLibrary()
            }
        }
    }

    public func reconcile() {
        let docks = manager.library.docks
        let liveIDs = Set(docks.map(\.id))

        // Remove controllers for deleted docks.
        for id in Array(controllers.keys) where !liveIDs.contains(id) {
            controllers[id]?.close()
            controllers.removeValue(forKey: id)
        }

        // Add/refresh controllers for live docks.
        for dock in docks {
            let controller: DockWindowController
            if let existing = controllers[dock.id] {
                controller = existing
            } else {
                controller = DockWindowController(dockID: dock.id, manager: manager, displayObserver: displayObserver)
                controllers[dock.id] = controller
            }

            let bound = displayObserver.screen(for: dock.screenID)
            if dock.isEnabled, bound != nil || dock.screenID == nil {
                controller.show()
            } else {
                controller.hide()
            }
        }
    }
}
