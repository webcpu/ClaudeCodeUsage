//
//  FileOperations.swift
//  File system operations for capture output
//

import Foundation

// MARK: - Directory Operations

func createOutputDirectory(_ url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

func outputPath<E>(for screenshot: Screenshot<E>, in directory: URL) -> URL {
    directory.appendingPathComponent("\(screenshot.name).png")
}

// MARK: - Manifest Operations

func writeManifest(_ results: [CaptureResult], to directory: URL) throws {
    let manifest = ManifestOutput.from(results: results, directory: directory)
    let data = try encodeManifest(manifest)
    let path = directory.appendingPathComponent(Config.manifestFilename)
    try data.write(to: path)
    print("Manifest: \(path.path)")
}

private func encodeManifest(_ manifest: ManifestOutput) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(manifest)
}
