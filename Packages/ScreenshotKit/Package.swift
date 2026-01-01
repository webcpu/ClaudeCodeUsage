// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ScreenshotKit",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "ScreenshotKit",
            targets: ["ScreenshotKit"]),
    ],
    targets: [
        .target(name: "ScreenshotKit", path: "Sources"),
    ]
)
