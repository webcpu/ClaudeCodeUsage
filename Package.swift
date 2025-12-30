// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClaudeUsage",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        // Re-export products from standalone packages
        .library(
            name: "ClaudeUsageCore",
            targets: ["ClaudeUsageCoreWrapper"]),
        .library(
            name: "ClaudeUsageData",
            targets: ["ClaudeUsageDataWrapper"]),
        .library(
            name: "ClaudeUsageUI",
            targets: ["ClaudeUsageUIWrapper"]),
    ],
    dependencies: [
        .package(path: "Packages/ClaudeUsageCore"),
        .package(path: "Packages/ClaudeUsageData"),
        .package(path: "Packages/ClaudeUsageUI"),
    ],
    targets: [
        // Thin wrappers that re-export standalone packages
        .target(
            name: "ClaudeUsageCoreWrapper",
            dependencies: [
                .product(name: "ClaudeUsageCore", package: "ClaudeUsageCore"),
            ],
            path: "Sources/Wrappers/Core"),

        .target(
            name: "ClaudeUsageDataWrapper",
            dependencies: [
                .product(name: "ClaudeUsageData", package: "ClaudeUsageData"),
            ],
            path: "Sources/Wrappers/Data"),

        .target(
            name: "ClaudeUsageUIWrapper",
            dependencies: [
                .product(name: "ClaudeUsageUI", package: "ClaudeUsageUI"),
            ],
            path: "Sources/Wrappers/UI"),
    ]
)

// Note: To run the app, use:
// swift run --package-path Packages/ClaudeUsageUI ClaudeCodeUsage
