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
        .library(
            name: "StornautLifecycle",
            targets: ["StornautLifecycle"]
        ),
        .executable(
            name: "SurveyorBenchmark",
            targets: ["SurveyorBenchmark"]
        ),
        .executable(
            name: "stornaut-rule-compiler",
            targets: ["StornautRuleCompiler"]
        ),
        .executable(
            name: "stornaut-lifecycle-spike",
            targets: ["StornautLifecycleSpike"]
        ),
    ],
    targets: [
        .target(
            name: "StornautCore",
            resources: [
                .copy("Resources/BuiltInRuleCatalog.json"),
            ],
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
        .target(
            name: "StornautLifecycle",
            dependencies: ["CLifecycleSupport"]
        ),
        .target(
            name: "CLifecycleSupport",
            path: "Sources/CLifecycleSupport",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedLibrary("bsm"),
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
        .executableTarget(
            name: "StornautLifecycleSpike",
            dependencies: ["StornautLifecycle"],
            path: "tools/StornautLifecycleSpike"
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
            name: "StornautLifecycleTests",
            dependencies: ["StornautLifecycle"]
        ),
        .testTarget(
            name: "RuleCompilerTests",
            dependencies: ["RuleCompilerKit", "StornautCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
