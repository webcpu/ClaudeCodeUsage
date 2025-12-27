// swift-tools-version: 6.0

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "TimingMacro",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "TimingMacro", targets: ["TimingMacro"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0")
    ],
    targets: [
        .macro(
            name: "TimingMacroMacros",
            dependencies: [
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        .target(
            name: "TimingMacro",
            dependencies: ["TimingMacroMacros"]
        ),
        .testTarget(
            name: "TimingMacroTests",
            dependencies: [
                "TimingMacroMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
            ]
        )
    ]
)
