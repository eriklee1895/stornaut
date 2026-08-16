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
        .library(
            name: "StornautInvestigation",
            targets: ["StornautInvestigation"]
        ),
        .library(
            name: "StornautInvestigationDiagnostic",
            type: .static,
            targets: ["StornautInvestigationDiagnostic"]
        ),
        .library(
            name: "StornautProbeBridge",
            targets: ["StornautProbeBridge"]
        ),
        .library(
            name: "StornautProcessSupport",
            targets: ["StornautProcessSupport"]
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
        .executable(
            name: "stornaut-capability-runtime-verifier",
            targets: ["StornautCapabilityRuntimeVerifier"]
        ),
    ],
    targets: [
        .target(
            name: "StornautCore",
            dependencies: ["CSQLiteSupport", "StornautProcessSupport"],
            resources: [
                .copy("Resources/BuiltInRuleCatalog.json"),
                .copy("Resources/BuiltInExecutionProfileCatalog.json"),
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        .target(
            name: "StornautCodex",
            dependencies: ["StornautProcessSupport"],
            exclude: ["ProbeBridge"],
            resources: [
                .copy("Schemas"),
            ]
        ),
        .target(
            name: "StornautProbeBridge",
            dependencies: ["StornautCodex", "StornautCore"],
            path: "Sources/StornautCodex/ProbeBridge"
        ),
        .target(
            name: "StornautProcessSupport"
        ),
        .target(
            name: "StornautLifecycle",
            dependencies: ["CLifecycleSupport"]
        ),
        .target(
            name: "StornautInvestigation",
            dependencies: [
                "StornautCore",
                "StornautCodex",
            ],
            resources: [
                .copy("Resources/investigation-prompt-v1.txt"),
            ]
        ),
        .target(
            name: "StornautInvestigationRuntime",
            dependencies: [
                "StornautCodex",
                "StornautCore",
                "StornautInvestigation",
                "StornautLifecycle",
            ]
        ),
        .target(
            name: "StornautInvestigationDiagnostic",
            dependencies: []
        ),
        .target(
            name: "CLifecycleSupport",
            path: "Sources/CLifecycleSupport",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedLibrary("bsm"),
            ]
        ),
        .target(
            name: "CSQLiteSupport",
            path: "Sources/CSQLiteSupport",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
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
        .executableTarget(
            name: "StornautCapabilityRuntimeVerifier",
            dependencies: ["StornautCodex"],
            path: "Tools/StornautCapabilityRuntimeVerifier"
        ),
        .testTarget(
            name: "StornautCoreTests",
            dependencies: ["StornautCore"]
        ),
        .testTarget(
            name: "StornautCodexTests",
            dependencies: [
                "StornautCodex",
                "StornautCore",
                "StornautProbeBridge",
                "StornautProcessSupport",
            ]
        ),
        .testTarget(
            name: "StornautLifecycleTests",
            dependencies: ["StornautLifecycle"]
        ),
        .testTarget(
            name: "StornautInvestigationTests",
            dependencies: [
                "StornautInvestigation",
                "StornautInvestigationRuntime",
                "StornautCore",
                "StornautCodex",
            ]
        ),
        .testTarget(
            name: "RuleCompilerTests",
            dependencies: ["RuleCompilerKit", "StornautCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
