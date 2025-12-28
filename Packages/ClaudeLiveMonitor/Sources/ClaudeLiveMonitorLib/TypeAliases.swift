//
//  TypeAliases.swift
//  ClaudeLiveMonitorLib
//

import Foundation

// MARK: - Public Type Aliases

/// Live monitor's usage entry type for real-time session monitoring.
///
/// When importing both ClaudeCodeUsage and ClaudeLiveMonitorLib, use this
/// alias to distinguish from `ClaudeCodeUsage.UsageEntry`:
/// ```swift
/// import ClaudeCodeUsage
/// import ClaudeLiveMonitorLib
///
/// let historicalEntry: ClaudeCodeUsage.UsageEntry = ...
/// let liveEntry: LiveUsageEntry = ...
/// ```
public typealias LiveUsageEntry = UsageEntry

/// Live monitor's session block type for grouping related usage entries.
///
/// Use this alias when both modules are imported to avoid naming conflicts
/// with `ClaudeCodeUsage.SessionBlock`.
public typealias LiveSessionBlock = SessionBlock

/// Live monitor's token counts type for tracking input/output/cache tokens.
///
/// Use this alias when both modules are imported to avoid naming conflicts
/// with `ClaudeCodeUsage.TokenCounts`.
public typealias LiveTokenCounts = TokenCounts