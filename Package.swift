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
        .executable(
            name: "stornaut-rule-compiler",
            targets: ["StornautRuleCompiler"]
        ),
    ],
    targets: [
        .target(
            name: "StornautCore",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
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
        .target(
            name: "RuleCompilerKit",
            dependencies: ["StornautCore"],
            path: "Tools/RuleCompilerKit"
        ),
        .executableTarget(
            name: "StornautRuleCompiler",
            dependencies: ["RuleCompilerKit"],
            path: "Tools/StornautRuleCompiler"
        ),
        .testTarget(
            name: "StornautCoreTests",
            dependencies: ["StornautCore"]
        ),
        .testTarget(
            name: "StornautCodexTests",
            dependencies: ["StornautCodex", "StornautCore"]
        ),
        .testTarget(
            name: "RuleCompilerTests",
            dependencies: ["RuleCompilerKit", "StornautCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
