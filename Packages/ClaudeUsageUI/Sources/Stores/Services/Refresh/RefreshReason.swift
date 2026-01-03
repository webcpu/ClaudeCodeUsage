//
//  RefreshReason.swift
//  Reasons that can trigger a data refresh
//

import Foundation

/// Describes why a refresh was triggered, used for cache invalidation decisions.
enum RefreshReason: Sendable {
    case manual
    case fileChange
    case dayChange
    case timer
    case appBecameActive
    case windowFocus
    case wakeFromSleep

    /// Whether this refresh reason should invalidate cached data.
    var shouldInvalidateCache: Bool {
        switch self {
        case .timer:
            false
        case .manual, .fileChange, .dayChange, .appBecameActive, .windowFocus, .wakeFromSleep:
            true
        }
    }
}
