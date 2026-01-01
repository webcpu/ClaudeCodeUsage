//
//  Execution.swift
//  Mid-level capture coordination
//

import Foundation

@MainActor
func captureAll<E: Sendable>(
    _ screenshots: [Screenshot<E>],
    env: E,
    outputDir: URL
) async -> [CaptureResult] {
    await withTaskGroup(of: CaptureResult.self, returning: [CaptureResult].self) { group in
        screenshots.forEach { screenshot in
            group.addTask { @MainActor in
                capture(screenshot, env: env, outputDir: outputDir)
            }
        }
        var results: [CaptureResult] = []
        for await result in group {
            results.append(result)
        }
        return results
    }
}

@MainActor
func capture<E>(_ screenshot: Screenshot<E>, env: E, outputDir: URL) -> CaptureResult {
    let path = outputPath(for: screenshot, in: outputDir)
    do {
        try renderAndSave(screenshot: screenshot, env: env, to: path)
        return .success(name: screenshot.name, path: path.path, size: screenshot.size)
    } catch {
        return .failure(name: screenshot.name, path: path.path, size: screenshot.size, error: error)
    }
}
