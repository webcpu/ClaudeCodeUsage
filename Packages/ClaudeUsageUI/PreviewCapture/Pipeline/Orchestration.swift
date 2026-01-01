//
//  Orchestration.swift
//  High-level pipeline orchestration
//

import Foundation
@testable import ClaudeUsageUI

@MainActor
func runCapture<M: CaptureManifest>(_ manifest: M.Type, targetFilter: String?) async throws {
    let env = try await M.makeEnvironment()
    let targets = try filterTargets(M.targets, by: targetFilter)
    try createOutputDirectory(M.outputDirectory)
    let results = await captureAllTargets(targets, env: env, outputDir: M.outputDirectory)
    results.forEach { print($0.logMessage) }
    try writeManifest(results, to: M.outputDirectory)
}

@MainActor
func listTargets<M: CaptureManifest>(_ manifest: M.Type) {
    print("Available capture targets:")
    M.targets
        .map { "  - \($0.name) (\(Int($0.size.width))x\(Int($0.size.height)))" }
        .forEach { print($0) }
}

private func filterTargets<E>(
    _ allTargets: [CaptureTarget<E>],
    by filter: String?
) throws -> [CaptureTarget<E>] {
    guard let filter else { return allTargets }
    guard let target = allTargets.first(where: { $0.name == filter }) else {
        throw CaptureError.targetNotFound(filter, available: allTargets.map(\.name))
    }
    return [target]
}
