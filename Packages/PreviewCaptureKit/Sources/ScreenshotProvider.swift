//
//  ScreenshotProvider.swift
//  Protocol for defining screenshots to capture
//

import SwiftUI

// MARK: - Screenshot

/// A view to capture as a PNG screenshot.
///
/// For apps with dependencies (Environment):
/// ```swift
/// Screenshot<MyEnv>(name: "Main", width: 800, height: 600) { env in
///     AnyView(MainView().environmentObject(env.store))
/// }
/// ```
///
/// For simple apps (no dependencies):
/// ```swift
/// Screenshot<Void>(name: "Main", width: 800, height: 600) {
///     MainView()
/// }
/// ```
public struct Screenshot<Environment>: Sendable {
    public let name: String
    public let size: CGSize
    public let view: @MainActor @Sendable (Environment) -> AnyView

    public init(
        name: String,
        width: CGFloat,
        height: CGFloat,
        view: @escaping @MainActor @Sendable (Environment) -> AnyView
    ) {
        self.name = name
        self.size = CGSize(width: width, height: height)
        self.view = view
    }
}

/// Convenience initializer for stateless views (no Environment needed).
public extension Screenshot where Environment == Void {
    init<V: View>(
        name: String,
        width: CGFloat,
        height: CGFloat,
        @ViewBuilder view: @escaping @MainActor @Sendable () -> V
    ) {
        self.init(name: name, width: width, height: height) { _ in AnyView(view()) }
    }
}

// MARK: - Screenshot Provider Protocol

/// Defines what views to capture for visual verification.
///
/// ## Quick Start (Simple App)
///
/// For apps without complex dependencies, use ``SimpleScreenshotProvider``:
///
/// ```swift
/// import PreviewCaptureKit
///
/// struct Screenshots: SimpleScreenshotProvider {
///     static var outputDirectory: URL {
///         URL(fileURLWithPath: "/tmp/MyApp")
///     }
///
///     static var screenshots: [Screenshot<Void>] {
///         [
///             .init(name: "MainView", width: 800, height: 600) {
///                 MainView()
///             },
///             .init(name: "Settings", width: 400, height: 300) {
///                 SettingsView()
///             },
///         ]
///     }
/// }
/// ```
///
/// ## Advanced Usage (App with Dependencies)
///
/// For apps that need to inject dependencies into views:
///
/// ```swift
/// import PreviewCaptureKit
///
/// struct Screenshots: ScreenshotProvider {
///     typealias Environment = AppEnvironment
///
///     static var outputDirectory: URL {
///         URL(fileURLWithPath: "/tmp/MyApp")
///     }
///
///     static var screenshots: [Screenshot<AppEnvironment>] {
///         [
///             .init(name: "Main", width: 800, height: 600) { env in
///                 AnyView(MainView().environment(env.store))
///             },
///         ]
///     }
///
///     static func makeEnvironment() async throws -> AppEnvironment {
///         let env = AppEnvironment()
///         await env.loadData()
///         return env
///     }
/// }
/// ```
///
/// ## Entry Point
///
/// Create an executable with:
/// ```swift
/// import PreviewCaptureKit
///
/// @main
/// struct ScreenshotCapture {
///     static func main() async { await run(Screenshots.self) }
/// }
/// ```
@MainActor
public protocol ScreenshotProvider {
    /// The type passed to each screenshot's view builder.
    /// Use `Void` for simple apps, or your app's environment type for dependency injection.
    associatedtype Environment: Sendable

    /// Directory where PNG files and manifest.json will be written.
    static var outputDirectory: URL { get }

    /// Views to capture. Each becomes a PNG file named `{name}.png`.
    static var screenshots: [Screenshot<Environment>] { get }

    /// Creates the environment passed to each screenshot's view builder.
    /// For simple apps using `SimpleScreenshotProvider`, this is provided automatically.
    static func makeEnvironment() async throws -> Environment
}

public extension ScreenshotProvider {
    static var renderScale: CGFloat { 2.0 }
}

// MARK: - Simple Screenshot Provider

/// Simplified protocol for apps without complex dependencies.
///
/// Use this when your views don't need injected dependencies:
///
/// ```swift
/// struct Screenshots: SimpleScreenshotProvider {
///     static var outputDirectory: URL {
///         URL(fileURLWithPath: "/tmp/MyApp")
///     }
///
///     static var screenshots: [Screenshot<Void>] {
///         [
///             .init(name: "Main", width: 800, height: 600) {
///                 ContentView()
///             },
///         ]
///     }
/// }
/// ```
public protocol SimpleScreenshotProvider: ScreenshotProvider where Environment == Void {}

public extension SimpleScreenshotProvider {
    static func makeEnvironment() async throws {}
}
