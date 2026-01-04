//
//  CaptureScreenshots.swift
//  High-level capture orchestration using CaptureService
//

import Foundation

/// Captures screenshots for a ScreenshotProvider.
///
/// This is a convenience function that creates a CaptureService and executes
/// the full capture pipeline. For more control, use CaptureService directly.
///
/// - Parameters:
///   - provider: The ScreenshotProvider type
///   - filter: Optional filter to capture only specific screenshots
/// - Throws: CaptureError if filter doesn't match or capture fails
@MainActor
public func captureScreenshots<S: ScreenshotProvider>(_ provider: S.Type, filter: String?) async throws {
    let env = try await S.makeEnvironment()

    let service = CaptureService(outputDirectory: S.outputDirectory)

    _ = try await service.execute(
        screenshots: S.screenshots,
        env: env,
        filter: filter
    )
}
