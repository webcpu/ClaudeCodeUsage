//
//  ImageRenderer.swift
//  Protocol for rendering views to images. This is the boundary between
//  pure functional code and impure I/O.
//

import AppKit
import SwiftUI

// MARK: - Protocol

/// Protocol for rendering SwiftUI views to image data.
/// This is the "impure shell" boundary for image rendering operations.
@MainActor
public protocol ImageRendering: Sendable {
    /// Renders a view to PNG data.
    ///
    /// - Parameters:
    ///   - view: The SwiftUI view to render
    ///   - size: The size to render at
    ///   - scale: The render scale (e.g., 2.0 for Retina)
    /// - Returns: PNG data representing the rendered view
    /// - Throws: CaptureError if rendering fails
    func render<V: View>(_ view: V, size: CGSize, scale: CGFloat) throws -> Data
}

// MARK: - Default Implementation

/// Default ImageRenderer using SwiftUI's ImageRenderer.
/// This is the production implementation that performs actual rendering.
public struct SwiftUIImageRenderer: ImageRendering {
    public init() {}

    @MainActor
    public func render<V: View>(_ view: V, size: CGSize, scale: CGFloat) throws -> Data {
        let framedView = view.frame(width: size.width, height: size.height)
        let renderer = SwiftUI.ImageRenderer(content: framedView)
        renderer.scale = scale

        guard let nsImage = renderer.nsImage else {
            throw CaptureError.renderFailed("SwiftUI ImageRenderer returned nil")
        }

        guard let pngData = nsImage.pngData else {
            throw CaptureError.pngConversionFailed("Failed to convert NSImage to PNG")
        }

        return pngData
    }
}

// MARK: - Mock Implementation

/// Mock ImageRenderer for testing.
/// Returns predetermined data without actual rendering.
public struct MockImageRenderer: ImageRendering {
    private let result: Result<Data, CaptureError>

    public init(returning data: Data) {
        self.result = .success(data)
    }

    public init(throwing error: CaptureError) {
        self.result = .failure(error)
    }

    /// Creates a mock that returns empty PNG data (1x1 transparent pixel).
    public static var empty: MockImageRenderer {
        MockImageRenderer(returning: Self.minimalPNG)
    }

    @MainActor
    public func render<V: View>(_ view: V, size: CGSize, scale: CGFloat) throws -> Data {
        try result.get()
    }

    /// Minimal valid PNG data (1x1 transparent pixel)
    private static let minimalPNG: Data = {
        // PNG header + minimal IHDR + IDAT + IEND for 1x1 transparent pixel
        Data([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1
            0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, // RGBA, etc
            0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, // IDAT chunk
            0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01,
            0x0D, 0x0A, 0x2D, 0xB4,
            0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, // IEND chunk
            0xAE, 0x42, 0x60, 0x82
        ])
    }()
}

// MARK: - NSImage Extension

private extension NSImage {
    var pngData: Data? {
        tiffRepresentation
            .flatMap { NSBitmapImageRep(data: $0) }
            .flatMap { $0.representation(using: .png, properties: [:]) }
    }
}
