//
//  ClaudeUsageCore.swift
//  ClaudeUsageCore
//
//  Domain layer for Claude usage tracking.
//  Contains models, protocols, and pure analytics functions.
//
//  Modules:
//    - Models: UsageEntry, TokenCounts, SessionBlock, UsageStats, etc.
//    - Protocols: UsageDataSource, SessionDataSource
//    - Analytics: PricingCalculator, UsageAggregator
//

import Foundation

// Re-export for convenience
public typealias Cost = Double
public typealias TokenCount = Int
