//
//  RefreshReason.swift
//  Reasons that can trigger a data refresh
//

import Foundation

// MARK: - RefreshReasonDescriptor

/// Describes the behavior characteristics of a refresh reason.
/// Adding new properties here automatically extends all RefreshReason cases.
public struct RefreshReasonDescriptor: Sendable {
    public let shouldInvalidateCache: Bool

    public init(shouldInvalidateCache: Bool) {
        self.shouldInvalidateCache = shouldInvalidateCache
    }
}

// MARK: - Registry

extension RefreshReasonDescriptor {
    /// Registry mapping each refresh reason to its descriptor.
    /// To add a new RefreshReason: add the case and register its descriptor here.
    public static let descriptors: [RefreshReason: RefreshReasonDescriptor] = [
        .manual: RefreshReasonDescriptor(shouldInvalidateCache: true),
        .fileChange: RefreshReasonDescriptor(shouldInvalidateCache: true),
        .dayChange: RefreshReasonDescriptor(shouldInvalidateCache: true),
        .timer: RefreshReasonDescriptor(shouldInvalidateCache: false),
        .appBecameActive: RefreshReasonDescriptor(shouldInvalidateCache: true),
        .windowFocus: RefreshReasonDescriptor(shouldInvalidateCache: true),
        .wakeFromSleep: RefreshReasonDescriptor(shouldInvalidateCache: true),
    ]
}

// MARK: - RefreshReason

/// Describes why a refresh was triggered, used for cache invalidation decisions.
public enum RefreshReason: Sendable, Hashable {
    case manual
    case fileChange
    case dayChange
    case timer
    case appBecameActive
    case windowFocus
    case wakeFromSleep

    private var descriptor: RefreshReasonDescriptor {
        RefreshReasonDescriptor.descriptors[self]!
    }

    /// Whether this refresh reason should invalidate cached data.
    public var shouldInvalidateCache: Bool { descriptor.shouldInvalidateCache }
}
