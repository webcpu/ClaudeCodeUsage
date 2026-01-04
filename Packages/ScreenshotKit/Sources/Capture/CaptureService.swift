//
//  CaptureService.swift
//  Composition layer that wires pure core with impure shell.
//

import Foundation
import SwiftUI

/// A functional capture service that composes pure request/response handling
/// with impure I/O for actual file and rendering operations.
///
/// # Architecture: Pure Core, Impure Shell
///
/// - `PathBuilder`: Pure functions building file paths
/// - `ManifestBuilder`: Pure functions building manifest data
/// - `ImageRendering`: Impure shell for actual rendering
/// - `FileWriting`: Impure shell for actual file I/O
/// - `CaptureService`: Composition layer wiring it all together
///
/// # Thread Safety
///
/// CaptureService is designed for use from the MainActor.
/// All rendering operations require MainActor context.
///
/// # Example
///
/// ```swift
/// let service = CaptureService(outputDirectory: URL(fileURLWithPath: "/tmp/screenshots"))
///
/// let result = await service.capture(screenshot, env: myEnvironment)
/// ```
@MainActor
public struct CaptureService: Sendable {
    /// The output directory for captured screenshots
    public let outputDirectory: URL

    /// The image renderer for rendering views
    public let imageRenderer: ImageRendering

    /// The file writer for file operations
    public let fileWriter: FileWriting

    /// The render scale for screenshots
    public let renderScale: CGFloat

    /// Creates a new capture service.
    ///
    /// - Parameters:
    ///   - outputDirectory: The directory to save screenshots
    ///   - imageRenderer: The image renderer to use (default: SwiftUIImageRenderer)
    ///   - fileWriter: The file writer to use (default: FileSystemWriter)
    ///   - renderScale: The render scale (default: from Config)
    public init(
        outputDirectory: URL,
        imageRenderer: ImageRendering = SwiftUIImageRenderer(),
        fileWriter: FileWriting = FileSystemWriter(),
        renderScale: CGFloat = Config.renderScale
    ) {
        self.outputDirectory = outputDirectory
        self.imageRenderer = imageRenderer
        self.fileWriter = fileWriter
        self.renderScale = renderScale
    }
}

// MARK: - Single Screenshot Capture

extension CaptureService {
    /// Captures a single screenshot.
    ///
    /// - Parameters:
    ///   - screenshot: The screenshot to capture
    ///   - env: The environment to pass to the view
    /// - Returns: A CaptureResult indicating success or failure
    public func capture<E>(_ screenshot: Screenshot<E>, env: E) -> CaptureResult {
        // Pure: Build output path
        let path = PathBuilder.outputPath(name: screenshot.name, in: outputDirectory)

        do {
            // Pure: Get view from screenshot
            let view = screenshot.view(env)

            // Impure: Render view to PNG data
            let data = try imageRenderer.render(view, size: screenshot.size, scale: renderScale)

            // Impure: Write data to file
            try fileWriter.write(data, to: path)

            return .success(name: screenshot.name, path: path.path, size: screenshot.size)
        } catch {
            return .failure(name: screenshot.name, path: path.path, size: screenshot.size, error: error)
        }
    }
}

// MARK: - Batch Capture

extension CaptureService {
    /// Captures multiple screenshots concurrently.
    ///
    /// - Parameters:
    ///   - screenshots: The screenshots to capture
    ///   - env: The environment to pass to views
    /// - Returns: Array of CaptureResults
    public func captureAll<E: Sendable>(
        _ screenshots: [Screenshot<E>],
        env: E
    ) async -> [CaptureResult] {
        await withTaskGroup(of: CaptureResult.self, returning: [CaptureResult].self) { group in
            for screenshot in screenshots {
                group.addTask { @MainActor in
                    self.capture(screenshot, env: env)
                }
            }

            var results: [CaptureResult] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }
}

// MARK: - Directory & Manifest Operations

extension CaptureService {
    /// Creates the output directory if it doesn't exist.
    public func createOutputDirectory() throws {
        try fileWriter.createDirectory(at: outputDirectory)
    }

    /// Writes a manifest file from capture results.
    ///
    /// - Parameter results: The capture results to include
    /// - Throws: Encoding or file write errors
    public func writeManifest(from results: [CaptureResult]) throws {
        // Pure: Build and encode manifest
        let data = try ManifestBuilder.buildAndEncode(from: results, directory: outputDirectory)

        // Pure: Build manifest path
        let path = PathBuilder.manifestPath(in: outputDirectory)

        // Impure: Write to file
        try fileWriter.write(data, to: path)
    }
}

// MARK: - Full Capture Pipeline

extension CaptureService {
    /// Executes the full capture pipeline for a screenshot provider.
    ///
    /// - Parameters:
    ///   - screenshots: The screenshots to capture
    ///   - env: The environment to pass to views
    ///   - filter: Optional filter to capture only specific screenshots
    /// - Returns: Array of CaptureResults
    /// - Throws: CaptureError if filter doesn't match any screenshot
    public func execute<E: Sendable>(
        screenshots: [Screenshot<E>],
        env: E,
        filter: String? = nil
    ) async throws -> [CaptureResult] {
        // Pure: Filter screenshots
        let filtered = try filterScreenshots(screenshots, by: filter)

        // Impure: Create output directory
        try createOutputDirectory()

        // Impure: Capture all screenshots
        let results = await captureAll(filtered, env: env)

        // Log results
        results.forEach { print($0.logMessage) }

        // Impure: Write manifest
        try writeManifest(from: results)
        print("Manifest: \(PathBuilder.manifestPath(in: outputDirectory).path)")

        return results
    }

    /// Filters screenshots by name.
    /// This is a pure function.
    private func filterScreenshots<E>(
        _ all: [Screenshot<E>],
        by filter: String?
    ) throws -> [Screenshot<E>] {
        guard let filter else { return all }
        guard let screenshot = all.first(where: { $0.name == filter }) else {
            throw CaptureError.screenshotNotFound(filter, available: all.map(\.name))
        }
        return [screenshot]
    }
}

// MARK: - Functional Configuration

extension CaptureService {
    /// Returns a new service with a different output directory.
    public func withOutputDirectory(_ url: URL) -> CaptureService {
        CaptureService(
            outputDirectory: url,
            imageRenderer: imageRenderer,
            fileWriter: fileWriter,
            renderScale: renderScale
        )
    }

    /// Returns a new service with a different image renderer.
    public func withImageRenderer(_ renderer: ImageRendering) -> CaptureService {
        CaptureService(
            outputDirectory: outputDirectory,
            imageRenderer: renderer,
            fileWriter: fileWriter,
            renderScale: renderScale
        )
    }

    /// Returns a new service with a different file writer.
    public func withFileWriter(_ writer: FileWriting) -> CaptureService {
        CaptureService(
            outputDirectory: outputDirectory,
            imageRenderer: imageRenderer,
            fileWriter: writer,
            renderScale: renderScale
        )
    }

    /// Returns a new service with a different render scale.
    public func withRenderScale(_ scale: CGFloat) -> CaptureService {
        CaptureService(
            outputDirectory: outputDirectory,
            imageRenderer: imageRenderer,
            fileWriter: fileWriter,
            renderScale: scale
        )
    }
}
