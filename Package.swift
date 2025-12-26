// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ClaudeCodeUsage",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "ClaudeCodeUsageKit",
            targets: ["ClaudeCodeUsageKit"]),
        .executable(
            name: "ClaudeCodeUsage",
            targets: ["ClaudeCodeUsage"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(path: "Packages/ClaudeLiveMonitor")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ClaudeCodeUsageKit",
            dependencies: [],
            path: "Sources/ClaudeCodeUsageKit"),
        .executableTarget(
            name: "ClaudeCodeUsage",
            dependencies: [
                "ClaudeCodeUsageKit",
                .product(name: "ClaudeLiveMonitorLib", package: "ClaudeLiveMonitor")
            ],
            path: "Sources/ClaudeCodeUsage"),
        .testTarget(
            name: "ClaudeCodeUsageKitTests",
            dependencies: ["ClaudeCodeUsageKit"],
            path: "Tests/ClaudeCodeUsageKitTests",
            swiftSettings: [
                .unsafeFlags(["-enable-testing"]),
                .define("ENABLE_CODE_COVERAGE", .when(configuration: .debug))
            ]),
        .testTarget(
            name: "ClaudeCodeUsageTests",
            dependencies: [
                "ClaudeCodeUsage",
                "ClaudeCodeUsageKit",
                .product(name: "ClaudeLiveMonitorLib", package: "ClaudeLiveMonitor")
            ],
            path: "Tests/ClaudeCodeUsageTests",
            swiftSettings: [
                .unsafeFlags(["-enable-testing"]),
                .define("ENABLE_CODE_COVERAGE", .when(configuration: .debug))
            ]),
    ]
)
