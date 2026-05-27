import SwiftUI
import AppCore
import DesignSystem
import WorkspaceKit

public struct DockHostView: View {
    @State private var hoveredItemID: UUID?
    private let dockID: UUID
    private let manager: DockManager

    public init(dockID: UUID, manager: DockManager) {
        self.dockID = dockID
        self.manager = manager
    }

    public var body: some View {
        if let dock = manager.library.docks.first(where: { $0.id == dockID }) {
            HStack(spacing: dock.appearance.spacing) {
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
            .padding(.horizontal, dock.appearance.paddingHorizontal)
            .padding(.vertical, dock.appearance.paddingVertical)
            .background(
                VisualEffectBlur(material: dock.appearance.blurMaterial.nsMaterial)
                    .opacity(dock.appearance.opacity)
            )
            .clipShape(RoundedRectangle(cornerRadius: dock.appearance.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: dock.appearance.cornerRadius, style: .continuous)
                    .stroke(borderColor(dock.appearance.border), lineWidth: dock.appearance.border?.width ?? 0)
            )
            .shadow(
                color: shadowColor(dock.appearance.shadow),
                radius: dock.appearance.shadow?.radius ?? 0,
                x: dock.appearance.shadow?.x ?? 0,
                y: dock.appearance.shadow?.y ?? 0
            )
        }
    }

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
