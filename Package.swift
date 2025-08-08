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
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ClaudeCodeUsage",
            targets: ["ClaudeCodeUsage"]),
        .executable(
            name: "UsageDashboardCLI",
            targets: ["UsageDashboardCLI"]),
        .executable(
            name: "UsageDashboardApp",
            targets: ["UsageDashboardApp"]),
        .executable(
            name: "SimpleCLI",
            targets: ["SimpleCLI"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(path: "Packages/ClaudeLiveMonitor")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ClaudeCodeUsage",
            dependencies: [],
            path: "Sources/ClaudeCodeUsage"),
        .executableTarget(
            name: "UsageDashboardCLI",
            dependencies: ["ClaudeCodeUsage"],
            path: "Sources/UsageDashboardCLI"),
        .executableTarget(
            name: "UsageDashboardApp",
            dependencies: [
                "ClaudeCodeUsage",
                .product(name: "ClaudeLiveMonitorLib", package: "ClaudeLiveMonitor")
            ],
            path: "Sources/UsageDashboardApp"),
        .executableTarget(
            name: "SimpleCLI",
            dependencies: ["ClaudeCodeUsage"],
            path: "Sources/SimpleCLI"),
        .testTarget(
            name: "ClaudeCodeUsageTests",
            dependencies: ["ClaudeCodeUsage"],
            path: "Tests/ClaudeCodeUsageTests"),
    ]
)