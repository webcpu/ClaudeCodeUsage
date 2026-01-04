//
//  ManifestBuilder.swift
//  Pure functions for building manifest data from capture results.
//  No side effects, easily testable.
//

import Foundation

/// Pure functions for building manifest output.
/// This is part of the "pure core" - no I/O, deterministic outputs.
public enum ManifestBuilder {

    /// Builds manifest output from capture results.
    /// This is a pure function - same inputs always produce the same output.
    ///
    /// - Parameters:
    ///   - results: The capture results
    ///   - directory: The output directory
    ///   - timestamp: The timestamp to use (default: current time)
    /// - Returns: The manifest output structure
    public static func build(
        from results: [CaptureResult],
        directory: URL,
        timestamp: Date = Date()
    ) -> ManifestOutput {
        ManifestOutput(
            timestamp: ISO8601DateFormatter().string(from: timestamp),
            outputDirectory: directory.path,
            screenshots: results
        )
    }

    /// Encodes manifest to JSON data.
    /// This is a pure function that transforms data.
    ///
    /// - Parameter manifest: The manifest to encode
    /// - Returns: JSON data with pretty printing and sorted keys
    /// - Throws: Encoding errors
    public static func encode(_ manifest: ManifestOutput) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(manifest)
    }

    /// Builds and encodes manifest in one step.
    ///
    /// - Parameters:
    ///   - results: The capture results
    ///   - directory: The output directory
    ///   - timestamp: The timestamp to use (default: current time)
    /// - Returns: Encoded JSON data
    /// - Throws: Encoding errors
    public static func buildAndEncode(
        from results: [CaptureResult],
        directory: URL,
        timestamp: Date = Date()
    ) throws -> Data {
        let manifest = build(from: results, directory: directory, timestamp: timestamp)
        return try encode(manifest)
    }
}
