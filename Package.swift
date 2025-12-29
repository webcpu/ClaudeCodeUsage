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
        // Legacy SDK (deprecated, use ClaudeUsageData)
        .library(
            name: "ClaudeCodeUsageKit",
            targets: ["ClaudeCodeUsageKit"]),
        // macOS menu bar app
        .executable(
            name: "ClaudeUsage",
            targets: ["ClaudeUsage"]),
        // CLI monitor (new unified CLI)
        .executable(
            name: "claude-usage",
            targets: ["ClaudeMonitorCLI"])
    ],
    dependencies: [
        .package(path: "Packages/TimingMacro")
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

        // MARK: - Legacy SDK (transitional, will be removed)

        .target(
            name: "ClaudeCodeUsageKit",
            dependencies: [
                "ClaudeUsageCore",
                .product(name: "TimingMacro", package: "TimingMacro")
            ],
            path: "Sources/ClaudeCodeUsageKit"),

        // MARK: - Presentation Layer

        .executableTarget(
            name: "ClaudeUsage",
            dependencies: [
                "ClaudeUsageCore",
                "ClaudeUsageData",
                .product(name: "ClaudeLiveMonitorLib", package: "ClaudeLiveMonitor")  // Transitional - for SessionMonitorService
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
            name: "ClaudeCodeUsageKitTests",
            dependencies: ["ClaudeCodeUsageKit"],
            path: "Tests/ClaudeCodeUsageKitTests",
            swiftSettings: [
                .unsafeFlags(["-enable-testing"]),
                .define("ENABLE_CODE_COVERAGE", .when(configuration: .debug))
            ]),

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

// Add ClaudeLiveMonitor as local dependency (transitional - will be merged into ClaudeUsageData)
package.dependencies.append(.package(path: "Packages/ClaudeLiveMonitor"))
