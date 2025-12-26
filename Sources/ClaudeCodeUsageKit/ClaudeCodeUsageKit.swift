//
//  ClaudeCodeUsageKit.swift
//  ClaudeCodeUsageKit
//
//  Main SDK entry point - exports all public APIs
//

import Foundation

/// ClaudeCodeUsageKit
///
/// A Swift SDK for accessing and analyzing Claude Code usage data.
///
/// ## Quick Start
/// ```swift
/// import ClaudeCodeUsageKit
///
/// let client = ClaudeUsageClient()
/// let stats = try await client.getUsageStats()
/// print("Total cost: \(stats.totalCost)")
/// ```
public struct ClaudeCodeUsageKit {
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
        ClaudeCodeUsageKit v\(version)
        Build Date: \(buildDate)
        Platform Support: \(isSupported ? "Yes" : "No")
        """
    }
}
