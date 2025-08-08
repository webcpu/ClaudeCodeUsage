// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ClaudeCodeUsage",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8)
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
            targets: ["SimpleCLI"]),
        .executable(
            name: "SimpleSync",
            targets: ["SimpleSync"]),
        .executable(
            name: "TestCLI",
            targets: ["TestCLI"]),
        .executable(
            name: "DebugCLI",
            targets: ["DebugCLI"]),
        .executable(
            name: "FinalTest",
            targets: ["FinalTest"]),
        .executable(
            name: "ExactTest",
            targets: ["ExactTest"]),
        .executable(
            name: "RefactoredTest",
            targets: ["RefactoredTest"]),
        .executable(
            name: "TestTimerCLI",
            targets: ["TestTimerCLI"]),
        .executable(
            name: "TestRefreshCLI",
            targets: ["TestRefreshCLI"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
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
            dependencies: ["ClaudeCodeUsage"],
            path: "Sources/UsageDashboardApp"),
        .executableTarget(
            name: "SimpleCLI",
            dependencies: ["ClaudeCodeUsage"],
            path: "Sources/SimpleCLI"),
        .executableTarget(
            name: "SimpleSync",
            dependencies: ["ClaudeCodeUsage"],
            path: "Sources/SimpleSync"),
        .executableTarget(
            name: "TestCLI",
            dependencies: ["ClaudeCodeUsage"],
            path: "Sources/TestCLI"),
        .executableTarget(
            name: "DebugCLI",
            dependencies: ["ClaudeCodeUsage"],
            path: "Sources/DebugCLI"),
        .executableTarget(
            name: "FinalTest",
            dependencies: ["ClaudeCodeUsage"],
            path: "Sources/FinalTest"),
        .executableTarget(
            name: "ExactTest",
            dependencies: ["ClaudeCodeUsage"],
            path: "Sources/ExactTest"),
        .executableTarget(
            name: "RefactoredTest",
            dependencies: ["ClaudeCodeUsage"],
            path: "Sources/RefactoredTest"),
        .executableTarget(
            name: "TestTimerCLI",
            dependencies: ["ClaudeCodeUsage"],
            path: "Sources/TestTimerCLI"),
        .executableTarget(
            name: "TestRefreshCLI",
            dependencies: ["ClaudeCodeUsage"],
            path: "Sources/TestRefreshCLI"),
        .testTarget(
            name: "ClaudeCodeUsageTests",
            dependencies: ["ClaudeCodeUsage"],
            path: "Tests/ClaudeCodeUsageTests"),
    ]
)