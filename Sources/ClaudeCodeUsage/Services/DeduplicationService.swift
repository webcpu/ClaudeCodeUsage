//
//  DeduplicationService.swift
//  ClaudeCodeUsage
//
//  Service for deduplicating usage entries (Single Responsibility Principle)
//

import Foundation

/// Protocol for deduplication strategies
public protocol DeduplicationStrategy {
    /// Check if an entry should be included based on deduplication logic
    func shouldInclude(messageId: String?, requestId: String?) -> Bool
    
    /// Reset the deduplication state
    func reset()
}

/// Default deduplication using messageId:requestId hash (matching Rust backend)
/// Thread-safe implementation using a serial queue
public class HashBasedDeduplication: DeduplicationStrategy {
    private var processedHashes: Set<String>
    private let queue = DispatchQueue(label: "com.claudeusage.deduplication", attributes: .concurrent)
    
    public init() {
        self.processedHashes = Set<String>()
    }
    
    public func shouldInclude(messageId: String?, requestId: String?) -> Bool {
        guard let messageId = messageId, let requestId = requestId else {
            return true // Include if we can't deduplicate
        }
        
        let uniqueHash = "\(messageId):\(requestId)"
        
        // Use barrier for thread-safe write operations
        var shouldInclude = false
        queue.sync(flags: .barrier) {
            if !processedHashes.contains(uniqueHash) {
                processedHashes.insert(uniqueHash)
                shouldInclude = true
            }
        }
        
        return shouldInclude
    }
    
    public func reset() {
        // Use barrier for thread-safe write operation
        queue.async(flags: .barrier) {
            self.processedHashes.removeAll()
        }
    }
}

/// No deduplication strategy (for testing or when deduplication is not needed)
public class NoDeduplication: DeduplicationStrategy {
    public init() {}
    
    public func shouldInclude(messageId: String?, requestId: String?) -> Bool {
        return true
    }
    
    public func reset() {
        // Nothing to reset
    }
}