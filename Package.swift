// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DockWindowKit",
    platforms: [.macOS(.v14)],
    products: [.library(name: "DockWindowKit", targets: ["DockWindowKit"])],
    dependencies: [
        .package(url: "https://github.com/akhlaqahmad/docked-appcore.git", branch: "main"),
        .package(url: "https://github.com/akhlaqahmad/docked-displaykit.git", branch: "main"),
        .package(url: "https://github.com/akhlaqahmad/docked-designsystem.git", branch: "main"),
        .package(url: "https://github.com/akhlaqahmad/docked-workspacekit.git", branch: "main")
    ],
    targets: [
        .target(
            name: "DockWindowKit",
            dependencies: [.product(name: "AppCore", package: "docked-appcore"), .product(name: "DisplayKit", package: "docked-displaykit"), .product(name: "DesignSystem", package: "docked-designsystem"), .product(name: "WorkspaceKit", package: "docked-workspacekit")]
        )
    ]
)
