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
            name: "ScreenshotCapture",
            targets: ["ScreenshotCapture"]),
    ],
    dependencies: [
        .package(path: "../ClaudeUsageCore"),
        .package(path: "../ClaudeUsageData"),
        .package(path: "../ScreenshotKit"),
    ],
    targets: [
        .target(
            name: "ClaudeUsageUI",
            dependencies: [
                "ClaudeUsageCore",
                "ClaudeUsageData",
                .product(name: "ScreenshotKit", package: "ScreenshotKit"),
            ],
            path: "Sources"),

        .executableTarget(
            name: "ScreenshotCapture",
            dependencies: [
                "ClaudeUsageUI",
                .product(name: "ScreenshotKit", package: "ScreenshotKit"),
            ],
            path: "ScreenshotCapture",
            swiftSettings: [
                .unsafeFlags(["-enable-testing"]),
            ]),

        .testTarget(
            name: "ClaudeUsageUITests",
            dependencies: [
                "ClaudeUsageUI",
                "ClaudeUsageData",
            ],
            path: "Tests",
            swiftSettings: [
                .unsafeFlags(["-enable-testing"]),
                .define("ENABLE_CODE_COVERAGE", .when(configuration: .debug)),
            ]),
    ]
)
