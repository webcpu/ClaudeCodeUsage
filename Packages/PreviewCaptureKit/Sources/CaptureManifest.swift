//
//  CaptureManifest.swift
//  Protocol for defining capture targets per module
//

import SwiftUI

// MARK: - Capture Target

/// A view to capture as a PNG image.
///
/// For apps with dependencies (Environment):
/// ```swift
/// CaptureTarget<MyEnv>(name: "Main", width: 800, height: 600) { env in
///     AnyView(MainView().environmentObject(env.store))
/// }
/// ```
///
/// For simple apps (no dependencies):
/// ```swift
/// CaptureTarget<Void>(name: "Main", width: 800, height: 600) {
///     MainView()
/// }
/// ```
public struct CaptureTarget<Environment>: Sendable {
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
public extension CaptureTarget where Environment == Void {
    init<V: View>(
        name: String,
        width: CGFloat,
        height: CGFloat,
        @ViewBuilder view: @escaping @MainActor @Sendable () -> V
    ) {
        self.init(name: name, width: width, height: height) { _ in AnyView(view()) }
    }
}

// MARK: - Capture Manifest Protocol

/// Defines what views to capture for visual verification.
///
/// ## Quick Start (Simple App)
///
/// For apps without complex dependencies, use ``SimpleCaptureManifest``:
///
/// ```swift
/// import PreviewCaptureKit
///
/// struct MyCaptures: SimpleCaptureManifest {
///     static var outputDirectory: URL {
///         URL(fileURLWithPath: "/tmp/MyApp")
///     }
///
///     static var targets: [CaptureTarget<Void>] {
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
/// extension AppEnvironment: CaptureManifest {
///     static var outputDirectory: URL {
///         URL(fileURLWithPath: "/tmp/MyApp")
///     }
///
///     static var targets: [CaptureTarget<AppEnvironment>] {
///         [
///             .init(name: "Main", width: 800, height: 600) { env in
///                 AnyView(MainView().environmentObject(env.store))
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
/// struct MyPreviewCapture {
///     static func main() async { await run(MyCaptures.self) }
/// }
/// ```
@MainActor
public protocol CaptureManifest {
    /// The type passed to each target's view builder.
    /// Use `Void` for simple apps, or your app's environment type for dependency injection.
    associatedtype Environment: Sendable

    /// Directory where PNG files and manifest.json will be written.
    static var outputDirectory: URL { get }

    /// Views to capture. Each becomes a PNG file named `{name}.png`.
    static var targets: [CaptureTarget<Environment>] { get }

    /// Creates the environment passed to each target's view builder.
    /// For simple apps using `SimpleCaptureManifest`, this is provided automatically.
    static func makeEnvironment() async throws -> Environment
}

public extension CaptureManifest {
    static var renderScale: CGFloat { 2.0 }
}

// MARK: - Simple Capture Manifest

/// Simplified protocol for apps without complex dependencies.
///
/// Use this when your views don't need injected dependencies:
///
/// ```swift
/// struct MyCaptures: SimpleCaptureManifest {
///     static var outputDirectory: URL {
///         URL(fileURLWithPath: "/tmp/MyApp")
///     }
///
///     static var targets: [CaptureTarget<Void>] {
///         [
///             .init(name: "Main", width: 800, height: 600) {
///                 ContentView()
///             },
///         ]
///     }
/// }
/// ```
public protocol SimpleCaptureManifest: CaptureManifest where Environment == Void {}

public extension SimpleCaptureManifest {
    static func makeEnvironment() async throws { }
}
