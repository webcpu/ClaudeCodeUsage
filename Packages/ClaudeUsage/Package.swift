// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClaudeUsage",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        // Main product - exports everything
        .library(name: "ClaudeUsage", targets: ["ClaudeUsage"]),
        // Aliases for backwards compatibility
        .library(name: "ClaudeUsageUI", targets: ["ClaudeUsage"]),
        .library(name: "ClaudeUsageCore", targets: ["ClaudeUsage"]),
        .library(name: "ClaudeUsageData", targets: ["ClaudeUsage"]),
        .executable(name: "ScreenshotCapture", targets: ["ScreenshotCapture"]),
    ],
    dependencies: [
        .package(url: "https://github.com/webcpu/ScreenshotKit", branch: "main"),
    ],
    targets: [
        // Single target with vertical slice architecture
        // Sources organized as: Shared, Analytics, Monitoring, App, Support
        .target(
            name: "ClaudeUsage",
            dependencies: [
                .product(name: "ScreenshotKit", package: "ScreenshotKit"),
            ],
            path: "Sources"
        ),

        // Screenshot capture executable
        .executableTarget(
            name: "ScreenshotCapture",
            dependencies: [
                "ClaudeUsage",
                .product(name: "ScreenshotKit", package: "ScreenshotKit"),
            ],
            path: "ScreenshotCapture",
            swiftSettings: [
                .unsafeFlags(["-enable-testing"]),
            ]
        ),

        // Tests
        .testTarget(
            name: "ClaudeUsageTests",
            dependencies: ["ClaudeUsage"],
            path: "Tests"
        ),
    ]
)
