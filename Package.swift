// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "quickwheel",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Quickwheel", targets: ["Quickwheel"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.0")
    ],
    targets: [
        .executableTarget(
            name: "Quickwheel",
            dependencies: ["QuickwheelCore"]
        ),
        .target(
            name: "QuickwheelCore",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ]
        ),
        .testTarget(
            name: "QuickwheelCoreTests",
            dependencies: ["QuickwheelCore"]
        )
    ]
)
