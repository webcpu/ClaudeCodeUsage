//
//  CaptureScreenshots.swift
//  High-level capture orchestration
//

import Foundation

@MainActor
public func captureScreenshots<S: ScreenshotProvider>(_ provider: S.Type, filter: String?) async throws {
    let env = try await S.makeEnvironment()
    let screenshots = try filterScreenshots(S.screenshots, by: filter)
    try createOutputDirectory(S.outputDirectory)
    let results = await captureAll(screenshots, env: env, outputDir: S.outputDirectory)
    results.forEach { print($0.logMessage) }
    try writeManifest(results, to: S.outputDirectory)
}

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
