//
//  Execution.swift
//  Mid-level capture coordination
//

import Foundation
@testable import ClaudeUsageUI

@MainActor
func captureAllTargets<E: Sendable>(
    _ targets: [CaptureTarget<E>],
    env: E,
    outputDir: URL
) async -> [CaptureResult] {
    await withTaskGroup(of: CaptureResult.self, returning: [CaptureResult].self) { group in
        targets.forEach { target in
            group.addTask { @MainActor in
                captureTarget(target, env: env, outputDir: outputDir)
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
func captureTarget<E>(_ target: CaptureTarget<E>, env: E, outputDir: URL) -> CaptureResult {
    let path = outputPath(for: target, in: outputDir)
    do {
        try renderAndSave(target: target, env: env, to: path)
        return .success(name: target.name, path: path.path, size: target.size)
    } catch {
        return .failure(name: target.name, path: path.path, size: target.size, error: error)
    }
}
