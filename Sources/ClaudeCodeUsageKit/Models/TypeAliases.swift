//
//  TypeAliases.swift
//  ClaudeCodeUsage
//
//  Type aliases to avoid naming conflicts between modules
//

import Foundation

// MARK: - Type Aliases for Disambiguation

/// Main usage entry type from ClaudeCodeUsage module
/// Used for historical data from Claude's usage files
public typealias ClaudeUsageEntry = UsageEntry

/// Type alias for the main module's usage stats
public typealias ClaudeUsageStats = UsageStats

/// Type alias for the main module's model usage
public typealias ClaudeModelUsage = ModelUsage

/// Type alias for the main module's daily usage
public typealias ClaudeDailyUsage = DailyUsage

/// Type alias for the main module's project usage
public typealias ClaudeProjectUsage = ProjectUsage

// Note: When importing both ClaudeCodeUsage and ClaudeLiveMonitorLib,
// use these type aliases to explicitly reference types from this module:
//
// Example:
//   import ClaudeCodeUsageKit
//   import ClaudeLiveMonitorLib
//
//   let historicalEntry: ClaudeCodeUsage.ClaudeUsageEntry = ...
//   let liveEntry: ClaudeLiveMonitorLib.UsageEntry = ...
//
// Or use module-qualified names directly:
//   let entry: ClaudeCodeUsage.UsageEntry = ...