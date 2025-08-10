//
//  TypeAliases.swift
//  ClaudeLiveMonitorLib
//
//  Type aliases for clarity when used alongside ClaudeCodeUsage
//

import Foundation

// MARK: - Type Aliases for Live Monitor Types

/// Live monitor's usage entry type
/// Used for real-time session monitoring
public typealias LiveUsageEntry = UsageEntry

/// Live monitor's session block type
public typealias LiveSessionBlock = SessionBlock

/// Live monitor's token counts type
public typealias LiveTokenCounts = TokenCounts

// Note: When importing both ClaudeCodeUsage and ClaudeLiveMonitorLib,
// use these type aliases or module-qualified names to avoid conflicts:
//
// Example:
//   import ClaudeCodeUsage
//   import ClaudeLiveMonitorLib
//
//   let historicalEntry: ClaudeCodeUsage.UsageEntry = ...
//   let liveEntry: ClaudeLiveMonitorLib.LiveUsageEntry = ...
//
// Or use fully qualified names:
//   let liveEntry: ClaudeLiveMonitorLib.UsageEntry = ...