import SwiftUI
import AppCore
import DesignSystem
import WorkspaceKit

public struct DockHostView: View {
    @State private var hoveredItemID: UUID?
    @State private var isDropTargeted = false
    private let dockID: UUID
    private let manager: DockManager

    public init(dockID: UUID, manager: DockManager) {
        self.dockID = dockID
        self.manager = manager
    }

    public var body: some View {
        if let dock = manager.library.docks.first(where: { $0.id == dockID }) {
            HStack(spacing: dock.appearance.spacing) {
                if dock.items.isEmpty {
                    // Empty hint — disappears as soon as the first item lands.
                    Text("Drop apps or files here")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                } else {
                    ForEach(dock.items) { item in
                        DockItemView(
                            item: item,
                            appearance: dock.appearance,
                            isHovered: hoveredItemID == item.id
                        )
                        .onHover { hovering in
                            hoveredItemID = hovering ? item.id : nil
                        }
                        .onTapGesture {
                            WorkspaceLauncher.open(item)
                        }
                    }
                }
            }
            .padding(.horizontal, dock.appearance.paddingHorizontal)
            .padding(.vertical, dock.appearance.paddingVertical)
            .background(
                VisualEffectBlur(material: dock.appearance.blurMaterial.nsMaterial)
                    .opacity(dock.appearance.opacity)
            )
            .clipShape(RoundedRectangle(cornerRadius: dock.appearance.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: dock.appearance.cornerRadius, style: .continuous)
                    .stroke(
                        isDropTargeted ? Color.accentColor : borderColor(dock.appearance.border),
                        lineWidth: isDropTargeted ? 2 : (dock.appearance.border?.width ?? 0)
                    )
            )
            .shadow(
                color: shadowColor(dock.appearance.shadow),
                radius: dock.appearance.shadow?.radius ?? 0,
                x: dock.appearance.shadow?.x ?? 0,
                y: dock.appearance.shadow?.y ?? 0
            )
            .dropDestination(for: URL.self) { urls, _ in
                addItems(from: urls)
                return !urls.isEmpty
            } isTargeted: { targeted in
                withAnimation(.easeOut(duration: 0.12)) {
                    isDropTargeted = targeted
                }
            }
        }
    }

    // MARK: - Drop handling

    /// Convert a list of file URLs (apps, files, folders) into `DockItem`s and
    /// add them to this dock. Silently ignores items that exceed the free-tier
    /// item limit — to surface that error to the user, route through a toast
    /// or banner in a follow-up.
    private func addItems(from urls: [URL]) {
        for url in urls {
            guard let item = Self.makeDockItem(from: url) else { continue }
            try? manager.addItem(item, to: dockID)
        }
    }

    /// Classify a file URL into the right `DockItem` variant.
    /// - `.app` extension → `AppItem` with bundle ID read from `Bundle(url:)`
    /// - directory → `FolderItem`
    /// - else → `FileItem`
    static func makeDockItem(from url: URL) -> DockItem? {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return nil }

        if url.pathExtension == "app" {
            let bundleID = Bundle(url: url)?.bundleIdentifier
                ?? "unknown.\(url.deletingPathExtension().lastPathComponent.lowercased())"
            let name = url.deletingPathExtension().lastPathComponent
            return .app(AppItem(bundleID: bundleID, appURL: url, displayName: name))
        }

        let displayName = url.lastPathComponent
        if isDir.boolValue {
            return .folder(FolderItem(path: url, displayName: displayName))
        }
        return .file(FileItem(path: url, displayName: displayName))
    }

    // MARK: - Styling helpers

    private func borderColor(_ style: DockBorderStyle?) -> Color {
        guard let style else { return .clear }
        return Color(hexARGB: style.colorHex) ?? .white.opacity(0.08)
    }

    private func shadowColor(_ style: DockShadowStyle?) -> Color {
        guard let style else { return .clear }
        return Color(hexARGB: style.colorHex) ?? .black.opacity(0.32)
    }
}

extension VisualMaterial {
    var nsMaterial: NSVisualEffectView.Material {
        switch self {
        case .hudWindow: return .hudWindow
        case .popover: return .popover
        case .sidebar: return .sidebar
        case .windowBackground: return .windowBackground
        case .contentBackground: return .contentBackground
        case .fullScreenUI: return .fullScreenUI
        case .titlebar: return .titlebar
        case .menu: return .menu
        case .headerView: return .headerView
        case .sheet: return .sheet
        }
    }
}
