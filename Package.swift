// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Stornaut",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .library(
            name: "StornautCore",
            targets: ["StornautCore"]
        ),
        .library(
            name: "StornautCodex",
            targets: ["StornautCodex"]
        ),
    ],
    targets: [
        .target(
            name: "StornautCore"
        ),
        .target(
            name: "StornautCodex"
        ),
        .testTarget(
            name: "StornautCoreTests",
            dependencies: ["StornautCore"]
        ),
        .testTarget(
            name: "StornautCodexTests",
            dependencies: ["StornautCodex"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
