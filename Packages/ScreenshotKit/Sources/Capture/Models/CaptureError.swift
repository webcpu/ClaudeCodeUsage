//
//  CaptureError.swift
//  Error types for capture operations
//

import Foundation

public enum CaptureError: Error, CustomStringConvertible, Sendable {
    case renderFailed(String)
    case pngConversionFailed(String)
    case screenshotNotFound(String, available: [String])

    public var description: String {
        switch self {
        case .renderFailed(let name):
            "Render failed: \(name)"
        case .pngConversionFailed(let name):
            "PNG conversion failed: \(name)"
        case .screenshotNotFound(let name, let available):
            "Screenshot '\(name)' not found. Available: \(available.joined(separator: ", "))"
        }
    }
}
