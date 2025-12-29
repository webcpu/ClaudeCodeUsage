// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClaudeUsage",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        // Domain layer - pure types, protocols, analytics
        .library(
            name: "ClaudeUsageCore",
            targets: ["ClaudeUsageCore"]),
        // Data layer - repository, parsing, monitoring
        .library(
            name: "ClaudeUsageData",
            targets: ["ClaudeUsageData"]),
        // macOS menu bar app
        .executable(
            name: "ClaudeUsage",
            targets: ["ClaudeUsage"]),
        // CLI monitor
        .executable(
            name: "claude-usage",
            targets: ["ClaudeMonitorCLI"])
    ],
    dependencies: [
        .package(path: "Packages/ClaudeLiveMonitor")  // Transitional - will be merged into ClaudeUsageData
    ],
    targets: [
        // MARK: - Domain Layer (no dependencies)

        .target(
            name: "ClaudeUsageCore",
            dependencies: [],
            path: "Sources/ClaudeUsageCore"),

        // MARK: - Data Layer (depends on Core)

        .target(
            name: "ClaudeUsageData",
            dependencies: ["ClaudeUsageCore"],
            path: "Sources/ClaudeUsageData"),

        // MARK: - Presentation Layer

        .executableTarget(
            name: "ClaudeUsage",
            dependencies: [
                "ClaudeUsageCore",
                "ClaudeUsageData",
                .product(name: "ClaudeLiveMonitorLib", package: "ClaudeLiveMonitor")
            ],
            path: "Sources/ClaudeUsage"),

        // MARK: - CLI

        .executableTarget(
            name: "ClaudeMonitorCLI",
            dependencies: ["ClaudeUsageData"],
            path: "Sources/ClaudeMonitorCLI"),

        // MARK: - Tests

        .testTarget(
            name: "ClaudeUsageCoreTests",
            dependencies: ["ClaudeUsageCore"],
            path: "Tests/ClaudeUsageCoreTests"),

        .testTarget(
            name: "ClaudeUsageDataTests",
            dependencies: ["ClaudeUsageData"],
            path: "Tests/ClaudeUsageDataTests"),

        .testTarget(
            name: "ClaudeUsageTests",
            dependencies: [
                "ClaudeUsage",
                "ClaudeUsageData"
            ],
            path: "Tests/ClaudeUsageTests",
            swiftSettings: [
                .unsafeFlags(["-enable-testing"]),
                .define("ENABLE_CODE_COVERAGE", .when(configuration: .debug))
            ]),
    ]
)
