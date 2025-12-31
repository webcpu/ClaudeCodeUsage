//
//  CaptureManifest.swift
//  Protocol for defining capture targets per module
//

import SwiftUI

// MARK: - Capture Target

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

// MARK: - Capture Manifest Protocol

@MainActor
public protocol CaptureManifest {
    associatedtype Environment
    static var outputDirectory: URL { get }
    static var targets: [CaptureTarget<Environment>] { get }
    static func makeEnvironment() async throws -> Environment
}

// MARK: - Defaults

public extension CaptureManifest {
    static var renderScale: CGFloat { 2.0 }
}
