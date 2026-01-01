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
            name: "PreviewCapture",
            targets: ["PreviewCapture"]),
    ],
    dependencies: [
        .package(path: "../ClaudeUsageCore"),
        .package(path: "../ClaudeUsageData"),
        .package(path: "../PreviewCaptureKit"),
    ],
    targets: [
        .target(
            name: "ClaudeUsageUI",
            dependencies: [
                "ClaudeUsageCore",
                "ClaudeUsageData",
                .product(name: "PreviewCaptureKit", package: "PreviewCaptureKit"),
            ],
            path: "Sources"),

        .executableTarget(
            name: "PreviewCapture",
            dependencies: [
                "ClaudeUsageUI",
                .product(name: "PreviewCaptureKit", package: "PreviewCaptureKit"),
            ],
            path: "PreviewCapture",
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
