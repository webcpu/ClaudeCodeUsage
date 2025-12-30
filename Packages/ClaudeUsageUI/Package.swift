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
            ],
            path: "Sources"),

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
