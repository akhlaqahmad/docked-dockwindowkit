import SwiftUI
import AppKit
import AppCore
import WorkspaceKit

struct DockItemView: View {
    let item: DockItem
    let appearance: DockAppearance
    let isHovered: Bool

    var body: some View {
        ZStack {
            iconImage
                .resizable()
                .interpolation(.high)
                .frame(width: scaledSize, height: scaledSize)
                .scaleEffect(isHovered && appearance.magnification.enabled ? appearance.magnification.scale : 1.0)
                .animation(.easeOut(duration: 0.16), value: isHovered)
        }
        .help(item.displayName)
        .accessibilityLabel(item.displayName)
    }

    private var scaledSize: CGFloat { appearance.iconSize }

    private var iconImage: Image {
        if let nsImage = IconResolver.resolve(item) {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "questionmark.square.dashed")
    }
}
