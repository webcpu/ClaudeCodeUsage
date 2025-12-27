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
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ClaudeCodeUsageKit",
            dependencies: [
                .product(name: "TimingMacro", package: "TimingMacro")
            ],
            path: "Sources/ClaudeCodeUsageKit",
            swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(
            name: "ClaudeCodeUsage",
            dependencies: [
                "ClaudeCodeUsageKit",
                .product(name: "ClaudeLiveMonitorLib", package: "ClaudeLiveMonitor")
            ],
            path: "Sources/ClaudeCodeUsage",
            swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(
            name: "ClaudeCodeUsageKitTests",
            dependencies: ["ClaudeCodeUsageKit"],
            path: "Tests/ClaudeCodeUsageKitTests",
            swiftSettings: [
                .swiftLanguageMode(.v5),
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
                .swiftLanguageMode(.v5),
                .unsafeFlags(["-enable-testing"]),
                .define("ENABLE_CODE_COVERAGE", .when(configuration: .debug))
            ]),
    ]
)
