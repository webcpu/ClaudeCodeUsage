//
//  CaptureResult.swift
//  Data types for capture results and manifest output
//

import Foundation

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

// MARK: - Manifest Output

struct ManifestOutput: Codable {
    let timestamp: String
    let outputDirectory: String
    let screenshots: [CaptureResult]

    static func from(results: [CaptureResult], directory: URL) -> ManifestOutput {
        ManifestOutput(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            outputDirectory: directory.path,
            screenshots: results
        )
    }
}
