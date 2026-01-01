//
//  CaptureError.swift
//  Error types for capture operations
//

import Foundation

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
