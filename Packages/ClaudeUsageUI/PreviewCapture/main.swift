//
//  main.swift
//  Generic preview capture tool for visual verification
//
//  Usage:
//    swift run PreviewCapture              # Capture all targets
//    swift run PreviewCapture MenuBar      # Capture specific target
//    swift run PreviewCapture --list       # List available targets
//

import AppKit
@testable import ClaudeUsageUI
import SwiftUI

// MARK: - Configuration

private enum Config {
    static let renderScale: CGFloat = 2.0
    static let manifestFilename = "manifest.json"
}

// MARK: - Capture Result

struct CaptureResult: Codable {
    let name: String
    let path: String
    let width: Int
    let height: Int
    let status: String
    let error: String?

    static func success(name: String, path: String, size: CGSize) -> CaptureResult {
        CaptureResult(
            name: name,
            path: path,
            width: Int(size.width),
            height: Int(size.height),
            status: "success",
            error: nil
        )
    }

    static func failure(name: String, path: String, size: CGSize, error: Error) -> CaptureResult {
        CaptureResult(
            name: name,
            path: path,
            width: Int(size.width),
            height: Int(size.height),
            status: "failed",
            error: error.localizedDescription
        )
    }

    var logMessage: String {
        "\(status == "success" ? "Saved" : "FAILED"): \(path)"
    }
}

struct CaptureManifestOutput: Codable {
    let timestamp: String
    let outputDirectory: String
    let captures: [CaptureResult]

    static func from(results: [CaptureResult], directory: URL) -> CaptureManifestOutput {
        CaptureManifestOutput(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            outputDirectory: directory.path,
            captures: results
        )
    }
}

// MARK: - Errors

enum CaptureError: Error, CustomStringConvertible {
    case renderFailed(String)
    case pngConversionFailed(String)
    case targetNotFound(String, available: [String])

    var description: String {
        switch self {
        case .renderFailed(let name):
            "Render failed: \(name)"
        case .pngConversionFailed(let name):
            "PNG conversion failed: \(name)"
        case .targetNotFound(let name, let available):
            "Target '\(name)' not found. Available: \(available.joined(separator: ", "))"
        }
    }
}

// MARK: - Capture Pipeline (High Level)

@MainActor
func runCapture<M: CaptureManifest>(_ manifest: M.Type, targetFilter: String?) async throws {
    let env = try await M.makeEnvironment()
    let targets = try filterTargets(M.targets, by: targetFilter)
    try createOutputDirectory(M.outputDirectory)
    let results = await captureAllTargets(targets, env: env, outputDir: M.outputDirectory)
    results.forEach { print($0.logMessage) }
    try writeManifest(results, to: M.outputDirectory)
}

// MARK: - Capture Pipeline (Mid Level)

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

// MARK: - Capture Pipeline (Low Level)

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

// MARK: - File Operations

private func createOutputDirectory(_ url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

private func outputPath<E>(for target: CaptureTarget<E>, in directory: URL) -> URL {
    directory.appendingPathComponent("\(target.name).png")
}

private func writeManifest(_ results: [CaptureResult], to directory: URL) throws {
    let manifest = CaptureManifestOutput.from(results: results, directory: directory)
    let data = try encodeManifest(manifest)
    let path = directory.appendingPathComponent(Config.manifestFilename)
    try data.write(to: path)
    print("Manifest: \(path.path)")
}

private func encodeManifest(_ manifest: CaptureManifestOutput) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(manifest)
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

// MARK: - List Targets

@MainActor
func listTargets<M: CaptureManifest>(_ manifest: M.Type) {
    print("Available capture targets:")
    M.targets
        .map { "  - \($0.name) (\(Int($0.size.width))x\(Int($0.size.height)))" }
        .forEach { print($0) }
}

// MARK: - CLI

private enum Command {
    case list
    case help
    case capture(target: String?)

    static func parse(_ args: [String]) -> Command {
        if args.contains("--list") { return .list }
        if args.contains("--help") || args.contains("-h") { return .help }
        return .capture(target: args.first { !$0.hasPrefix("-") })
    }
}

@main
struct PreviewCaptureApp {
    static func main() async {
        await execute(Command.parse(Array(CommandLine.arguments.dropFirst())))
    }

    private static func execute(_ command: Command) async {
        switch command {
        case .list:
            await listTargets(AppEnvironment.self)
        case .help:
            printUsage()
        case .capture(let target):
            await executeCapture(target: target)
        }
    }

    private static func executeCapture(target: String?) async {
        do {
            try await runCapture(AppEnvironment.self, targetFilter: target)
            print("Capture complete.")
        } catch {
            print("Error: \(error)")
            exit(1)
        }
    }

    private static func printUsage() {
        print("""
        PreviewCapture - Visual verification tool for SwiftUI views

        Usage:
          swift run PreviewCapture              Capture all targets
          swift run PreviewCapture <name>       Capture specific target
          swift run PreviewCapture --list       List available targets
          swift run PreviewCapture --help       Show this help

        Output:
          PNG files and manifest.json are written to the output directory.
          Read manifest.json for structured results.

        Example:
          swift run PreviewCapture MenuBar
          cat /tmp/ClaudeUsageUI/manifest.json
        """)
    }
}

// MARK: - Extensions

private extension NSImage {
    var pngData: Data? {
        tiffRepresentation
            .flatMap { NSBitmapImageRep(data: $0) }
            .flatMap { $0.representation(using: .png, properties: [:]) }
    }
}
