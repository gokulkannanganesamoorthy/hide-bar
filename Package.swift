// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HideBar",
    platforms: [
        .macOS("27.0")
    ],
    products: [
        .executable(name: "HideBar", targets: ["HideBar"]),
    ],
    dependencies: [
        .package(path: "Packages/PelmetCore"),
        .package(path: "Packages/PelmetEngine"),
    ],
    targets: [
        .executableTarget(
            name: "HideBar",
            dependencies: [
                .product(name: "PelmetCore", package: "PelmetCore"),
                .product(name: "PelmetEngine", package: "PelmetEngine"),
            ],
            path: "Sources/HideBar"
        )
    ]
)
