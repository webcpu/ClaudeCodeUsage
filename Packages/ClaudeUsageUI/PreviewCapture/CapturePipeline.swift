//
//  CapturePipeline.swift
//  Core capture pipeline: orchestration, execution, and rendering
//

import AppKit
import SwiftUI
@testable import ClaudeUsageUI

// MARK: - High Level (Orchestration)

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

// MARK: - Mid Level (Coordination)

@MainActor
private func captureAllTargets<E: Sendable>(
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
private func captureTarget<E>(_ target: CaptureTarget<E>, env: E, outputDir: URL) -> CaptureResult {
    let path = outputPath(for: target, in: outputDir)
    do {
        try renderAndSave(target: target, env: env, to: path)
        return .success(name: target.name, path: path.path, size: target.size)
    } catch {
        return .failure(name: target.name, path: path.path, size: target.size, error: error)
    }
}

// MARK: - Low Level (Rendering)

@MainActor
private func renderAndSave<E>(target: CaptureTarget<E>, env: E, to path: URL) throws {
    let view = target.view(env)
    let image = try renderImage(from: view, size: target.size, name: target.name)
    let data = try convertToPNG(image, name: target.name)
    try data.write(to: path)
}

@MainActor
private func renderImage<V: View>(from view: V, size: CGSize, name: String) throws -> NSImage {
    let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
    renderer.scale = Config.renderScale
    guard let image = renderer.nsImage else {
        throw CaptureError.renderFailed(name)
    }
    return image
}

private func convertToPNG(_ image: NSImage, name: String) throws -> Data {
    guard let data = image.pngData else {
        throw CaptureError.pngConversionFailed(name)
    }
    return data
}

// MARK: - Target Filtering

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
