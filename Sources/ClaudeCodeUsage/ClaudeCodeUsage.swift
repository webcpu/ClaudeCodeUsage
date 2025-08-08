//
//  ClaudeUsageSDK.swift
//  ClaudeUsageSDK
//
//  Main SDK entry point - exports all public APIs
//

import Foundation

/// ClaudeUsageSDK
/// 
/// A Swift SDK for accessing and analyzing Claude Code usage data.
/// 
/// ## Quick Start
/// ```swift
/// import ClaudeCodeUsage
/// 
/// let client = ClaudeUsageClient()
/// let stats = try await client.getUsageStats()
/// print("Total cost: \(stats.totalCost)")
/// ```
public struct ClaudeUsageSDK {
    /// SDK Version
    public static let version = "1.0.0"
    
    /// SDK Build Date
    public static let buildDate = "2025-08-07"
    
    /// Check if the SDK is compatible with the current platform
    public static var isSupported: Bool {
        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
        return true
        #else
        return false
        #endif
    }
    
    /// Get SDK information
    public static var info: String {
        """
        ClaudeUsageSDK v\(version)
        Build Date: \(buildDate)
        Platform Support: \(isSupported ? "Yes" : "No")
        """
    }
}
