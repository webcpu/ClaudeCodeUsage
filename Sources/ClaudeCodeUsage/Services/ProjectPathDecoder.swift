//
//  ProjectPathDecoder.swift
//  ClaudeCodeUsage
//
//  Service for decoding project paths (Single Responsibility Principle)
//

import Foundation

/// Protocol for decoding project paths
public protocol ProjectPathDecoderProtocol {
    /// Decode an encoded project path to its original form
    func decode(_ encodedPath: String) -> String
}

/// Default implementation for decoding Claude project paths
public struct ProjectPathDecoder: ProjectPathDecoderProtocol {
    
    public init() {}
    
    public func decode(_ encodedPath: String) -> String {
        // Decode the project path - dashes replace slashes
        // Example: -Users-liang-Downloads -> /Users/liang/Downloads
        
        // Remove leading dash and replace remaining dashes with slashes
        if encodedPath.hasPrefix("-") {
            let pathWithoutLeadingDash = String(encodedPath.dropFirst())
            return "/" + pathWithoutLeadingDash.replacingOccurrences(of: "-", with: "/")
        }
        
        // Fallback for unexpected formats
        return encodedPath.replacingOccurrences(of: "-", with: "/")
    }
}