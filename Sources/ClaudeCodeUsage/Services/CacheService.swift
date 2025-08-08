//
//  CacheService.swift
//  ClaudeCodeUsage
//
//  Caching layer for expensive calculations with time-based expiration
//

import Foundation

/// Protocol for cache storage
public protocol CacheStorageProtocol {
    associatedtype Key: Hashable
    associatedtype Value
    
    func get(_ key: Key) -> Value?
    func set(_ key: Key, value: Value)
    func remove(_ key: Key)
    func removeAll()
}

/// Time-based cache entry
private struct CacheEntry<Value> {
    let value: Value
    let timestamp: Date
    let ttl: TimeInterval
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > ttl
    }
}

/// Thread-safe memory cache with TTL support
public final class MemoryCache<Key: Hashable, Value>: CacheStorageProtocol {
    private var storage: [Key: CacheEntry<Value>] = [:]
    private let queue = DispatchQueue(label: "com.claudecodeusage.cache", attributes: .concurrent)
    private let defaultTTL: TimeInterval
    
    public init(defaultTTL: TimeInterval = 300) { // 5 minutes default
        self.defaultTTL = defaultTTL
    }
    
    public func get(_ key: Key) -> Value? {
        queue.sync {
            guard let entry = storage[key], !entry.isExpired else {
                storage.removeValue(forKey: key)
                return nil
            }
            return entry.value
        }
    }
    
    public func set(_ key: Key, value: Value, ttl: TimeInterval? = nil) {
        queue.async(flags: .barrier) {
            let entry = CacheEntry(value: value, timestamp: Date(), ttl: ttl ?? self.defaultTTL)
            self.storage[key] = entry
        }
    }
    
    public func set(_ key: Key, value: Value) {
        set(key, value: value, ttl: defaultTTL)
    }
    
    public func remove(_ key: Key) {
        queue.async(flags: .barrier) {
            self.storage.removeValue(forKey: key)
        }
    }
    
    public func removeAll() {
        queue.async(flags: .barrier) {
            self.storage.removeAll()
        }
    }
    
    /// Remove expired entries
    public func evictExpired() {
        queue.async(flags: .barrier) {
            let now = Date()
            self.storage = self.storage.filter { _, entry in
                !entry.isExpired
            }
        }
    }
}

/// Cache key for usage statistics
public struct UsageStatsCacheKey: Hashable {
    let startDate: Date
    let endDate: Date
    let basePath: String
    
    public init(startDate: Date, endDate: Date, basePath: String) {
        self.startDate = startDate
        self.endDate = endDate
        self.basePath = basePath
    }
}

/// Cached repository wrapper
public class CachedUsageRepository {
    private let repository: UsageRepository
    private let cache: MemoryCache<UsageStatsCacheKey, UsageStats>
    
    public init(repository: UsageRepository, cacheTTL: TimeInterval = 60) {
        self.repository = repository
        self.cache = MemoryCache(defaultTTL: cacheTTL)
    }
    
    public func getUsageStats(startDate: Date? = nil, endDate: Date? = nil) async throws -> UsageStats {
        let start = startDate ?? Date.distantPast
        let end = endDate ?? Date()
        let cacheKey = UsageStatsCacheKey(
            startDate: start,
            endDate: end,
            basePath: repository.basePath
        )
        
        // Check cache first
        if let cachedStats = cache.get(cacheKey) {
            #if DEBUG
            print("[CachedRepository] Cache hit for key: \(cacheKey)")
            #endif
            return cachedStats
        }
        
        // Cache miss - load from repository
        #if DEBUG
        print("[CachedRepository] Cache miss, loading from repository")
        #endif
        let stats = try await repository.getUsageStats()
        
        // Store in cache
        cache.set(cacheKey, value: stats)
        
        return stats
    }
    
    public func invalidateCache() {
        cache.removeAll()
    }
}