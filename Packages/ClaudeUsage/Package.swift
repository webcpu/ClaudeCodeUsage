// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClaudeUsage",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(name: "ClaudeUsageUI", targets: ["ClaudeUsageUI"]),
        .library(name: "ClaudeUsageCore", targets: ["ClaudeUsageCore"]),
        .library(name: "ClaudeUsageData", targets: ["ClaudeUsageData"]),
        .executable(name: "ScreenshotCapture", targets: ["ScreenshotCapture"]),
    ],
    dependencies: [
        .package(path: "../ScreenshotKit"),
    ],
    targets: [
        // Layer 0: Core (no dependencies)
        .target(
            name: "ClaudeUsageCore",
            path: "Sources/Core"
        ),

        // Layer 1: Data (depends on Core)
        .target(
            name: "ClaudeUsageData",
            dependencies: ["ClaudeUsageCore"],
            path: "Sources/Data"
        ),

        // Layer 2: UI (depends on Core, Data)
        .target(
            name: "ClaudeUsageUI",
            dependencies: [
                "ClaudeUsageCore",
                "ClaudeUsageData",
                .product(name: "ScreenshotKit", package: "ScreenshotKit"),
            ],
            path: "Sources/UI"
        ),

        // Screenshot capture executable
        .executableTarget(
            name: "ScreenshotCapture",
            dependencies: [
                "ClaudeUsageUI",
                .product(name: "ScreenshotKit", package: "ScreenshotKit"),
            ],
            path: "ScreenshotCapture",
            swiftSettings: [
                .unsafeFlags(["-enable-testing"]),
            ]
        ),

        // Tests
        .testTarget(
            name: "ClaudeUsageCoreTests",
            dependencies: ["ClaudeUsageCore"],
            path: "Tests/CoreTests"
        ),

        .testTarget(
            name: "ClaudeUsageDataTests",
            dependencies: ["ClaudeUsageData"],
            path: "Tests/DataTests"
        ),

        .testTarget(
            name: "ClaudeUsageUITests",
            dependencies: ["ClaudeUsageUI", "ClaudeUsageData"],
            path: "Tests/UITests",
            swiftSettings: [
                .unsafeFlags(["-enable-testing"]),
                .define("ENABLE_CODE_COVERAGE", .when(configuration: .debug)),
            ]
        ),
    ]
)
