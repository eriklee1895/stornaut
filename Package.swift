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
        .executable(
            name: "SurveyorBenchmark",
            targets: ["SurveyorBenchmark"]
        ),
    ],
    targets: [
        .target(
            name: "StornautCore"
        ),
        .target(
            name: "StornautCodex",
            dependencies: ["StornautCore"],
            resources: [
                .copy("Schemas"),
            ]
        ),
        .executableTarget(
            name: "SurveyorBenchmark",
            dependencies: ["StornautCore"],
            path: "Benchmarks/SurveyorBenchmark"
        ),
        .testTarget(
            name: "StornautCoreTests",
            dependencies: ["StornautCore"]
        ),
        .testTarget(
            name: "StornautCodexTests",
            dependencies: ["StornautCodex", "StornautCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
