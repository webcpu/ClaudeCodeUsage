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
        // UI layer - SwiftUI views and stores
        .library(
            name: "ClaudeUsageUI",
            targets: ["ClaudeUsageUI"]),
        // macOS menu bar app
        .executable(
            name: "ClaudeCodeUsage",
            targets: ["ClaudeUsage"])
    ],
    dependencies: [],
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

        // MARK: - UI Layer (SwiftUI views, stores)

        .target(
            name: "ClaudeUsageUI",
            dependencies: [
                "ClaudeUsageCore",
                "ClaudeUsageData"
            ],
            path: "Sources/ClaudeUsageUI"),

        // MARK: - App Entry Point

        .executableTarget(
            name: "ClaudeUsage",
            dependencies: [
                "ClaudeUsageUI"
            ],
            path: "Sources/ClaudeUsage"),

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
                "ClaudeUsageUI",
                "ClaudeUsageData"
            ],
            path: "Tests/ClaudeUsageTests",
            swiftSettings: [
                .unsafeFlags(["-enable-testing"]),
                .define("ENABLE_CODE_COVERAGE", .when(configuration: .debug))
            ]),
    ]
)
