//
//  CaptureError.swift
//  Error types for capture operations
//

import Foundation

enum CaptureError: Error, CustomStringConvertible {
    case renderFailed(String)
    case pngConversionFailed(String)
    case screenshotNotFound(String, available: [String])

    var description: String {
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
