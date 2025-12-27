// swift-tools-version: 6.0

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
        .package(path: "Packages/ClaudeLiveMonitor"),
        .package(path: "Packages/TimingMacro")
    ],
    targets: [
        .target(
            name: "ClaudeCodeUsageKit",
            dependencies: [
                .product(name: "TimingMacro", package: "TimingMacro")
            ],
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
