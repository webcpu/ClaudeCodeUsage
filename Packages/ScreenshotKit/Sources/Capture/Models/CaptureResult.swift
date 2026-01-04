//
//  CaptureResult.swift
//  Data types for capture results and manifest output
//

import Foundation

// MARK: - Capture Result

public struct CaptureResult: Codable, Sendable {
    public let name: String
    public let path: String
    public let width: Int
    public let height: Int
    public let status: String
    public let error: String?

    public static func success(name: String, path: String, size: CGSize) -> CaptureResult {
        CaptureResult(
            name: name,
            path: path,
            width: Int(size.width),
            height: Int(size.height),
            status: "success",
            error: nil
        )
    }

    public static func failure(name: String, path: String, size: CGSize, error: Error) -> CaptureResult {
        CaptureResult(
            name: name,
            path: path,
            width: Int(size.width),
            height: Int(size.height),
            status: "failed",
            error: error.localizedDescription
        )
    }

    public var logMessage: String {
        "\(status == "success" ? "Saved" : "FAILED"): \(path)"
    }
}

// MARK: - Manifest Output

public struct ManifestOutput: Codable, Sendable {
    public let timestamp: String
    public let outputDirectory: String
    public let screenshots: [CaptureResult]

    public init(timestamp: String, outputDirectory: String, screenshots: [CaptureResult]) {
        self.timestamp = timestamp
        self.outputDirectory = outputDirectory
        self.screenshots = screenshots
    }

    public static func from(results: [CaptureResult], directory: URL) -> ManifestOutput {
        ManifestOutput(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            outputDirectory: directory.path,
            screenshots: results
        )
    }
}
