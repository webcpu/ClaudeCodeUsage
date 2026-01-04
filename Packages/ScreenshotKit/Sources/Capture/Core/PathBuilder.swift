//
//  PathBuilder.swift
//  Pure functions for building file paths from capture specifications.
//  No side effects, easily testable.
//

import Foundation

/// Pure functions for building file paths.
/// This is part of the "pure core" - no I/O, deterministic outputs.
public enum PathBuilder {

    /// Builds the output path for a screenshot.
    /// This is a pure function - same inputs always produce the same output.
    ///
    /// - Parameters:
    ///   - name: The screenshot name
    ///   - directory: The output directory
    /// - Returns: The full URL for the PNG file
    public static func outputPath(name: String, in directory: URL) -> URL {
        directory.appendingPathComponent("\(name).png")
    }

    /// Builds the manifest file path.
    ///
    /// - Parameters:
    ///   - directory: The output directory
    ///   - filename: The manifest filename (default: from Config)
    /// - Returns: The full URL for the manifest file
    public static func manifestPath(in directory: URL, filename: String = Config.manifestFilename) -> URL {
        directory.appendingPathComponent(filename)
    }

    /// Builds output paths for multiple screenshots.
    ///
    /// - Parameters:
    ///   - names: The screenshot names
    ///   - directory: The output directory
    /// - Returns: Dictionary mapping names to their output URLs
    public static func outputPaths(names: [String], in directory: URL) -> [String: URL] {
        Dictionary(uniqueKeysWithValues: names.map { ($0, outputPath(name: $0, in: directory)) })
    }
}
