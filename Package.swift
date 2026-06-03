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
    targets: [
        .executableTarget(
            name: "Quickwheel",
            dependencies: ["QuickwheelCore"]
        ),
        .target(
            name: "QuickwheelCore"
        ),
        .testTarget(
            name: "QuickwheelCoreTests",
            dependencies: ["QuickwheelCore"]
        )
    ]
)
