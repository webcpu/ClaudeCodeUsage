//
//  FileOperations.swift
//  File system operations for capture output
//

import Foundation

// MARK: - Directory Operations

func createOutputDirectory(_ url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

func outputPath<E>(for target: CaptureTarget<E>, in directory: URL) -> URL {
    directory.appendingPathComponent("\(target.name).png")
}

// MARK: - Manifest Operations

func writeManifest(_ results: [CaptureResult], to directory: URL) throws {
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
