// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClaudeUsageUI",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "ClaudeUsageUI",
            targets: ["ClaudeUsageUI"]),
        .executable(
            name: "ClaudeCodeUsage",
            targets: ["ClaudeCodeUsage"]),
    ],
    dependencies: [
        .package(path: "../ClaudeUsageCore"),
        .package(path: "../ClaudeUsageData"),
    ],
    targets: [
        .target(
            name: "ClaudeUsageUI",
            dependencies: [
                "ClaudeUsageCore",
                "ClaudeUsageData",
            ]),

        .executableTarget(
            name: "ClaudeCodeUsage",
            dependencies: ["ClaudeUsageUI"]),

        .testTarget(
            name: "ClaudeUsageUITests",
            dependencies: [
                "ClaudeUsageUI",
                "ClaudeUsageData",
            ],
            swiftSettings: [
                .unsafeFlags(["-enable-testing"]),
                .define("ENABLE_CODE_COVERAGE", .when(configuration: .debug)),
            ]),
    ]
)
