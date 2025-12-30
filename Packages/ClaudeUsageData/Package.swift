// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClaudeUsageData",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "ClaudeUsageData",
            targets: ["ClaudeUsageData"]),
    ],
    dependencies: [
        .package(path: "../ClaudeUsageCore"),
    ],
    targets: [
        .target(
            name: "ClaudeUsageData",
            dependencies: ["ClaudeUsageCore"],
            path: "Sources"),

        .testTarget(
            name: "ClaudeUsageDataTests",
            dependencies: ["ClaudeUsageData"],
            path: "Tests"),
    ]
)
