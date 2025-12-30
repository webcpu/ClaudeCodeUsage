// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClaudeUsageCore",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "ClaudeUsageCore",
            targets: ["ClaudeUsageCore"]),
    ],
    targets: [
        .target(
            name: "ClaudeUsageCore",
            dependencies: []),

        .testTarget(
            name: "ClaudeUsageCoreTests",
            dependencies: ["ClaudeUsageCore"]),
    ]
)
