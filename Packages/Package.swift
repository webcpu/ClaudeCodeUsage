// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeLiveMonitor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "claude-monitor",
            targets: ["ClaudeLiveMonitor"]
        ),
        .library(
            name: "ClaudeLiveMonitorLib",
            targets: ["ClaudeLiveMonitorLib"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "ClaudeLiveMonitor",
            dependencies: ["ClaudeLiveMonitorLib"],
            path: "Sources/ClaudeLiveMonitor"
        ),
        .target(
            name: "ClaudeLiveMonitorLib",
            dependencies: [],
            path: "Sources/ClaudeLiveMonitorLib"
        ),
        .testTarget(
            name: "ClaudeLiveMonitorTests",
            dependencies: ["ClaudeLiveMonitorLib"],
            path: "Tests/ClaudeLiveMonitorTests"
        )
    ]
)