//
//  UsageRepositoryBuilder.swift
//  ClaudeCodeUsage
//
//  Builder pattern for flexible repository construction
//

import Foundation

/// Builder for creating UsageRepository instances with flexible configuration
public class UsageRepositoryBuilder {
    private var fileSystem: FileSystemProtocol?
    private var parser: UsageDataParserProtocol?
    private var pathDecoder: ProjectPathDecoderProtocol?
    private var aggregator: StatisticsAggregatorProtocol?
    private var basePath: String?
    private var enableRetry: Bool = false
    private var enableCircuitBreaker: Bool = false
    private var enableCache: Bool = false
    private var retryConfiguration: RetryConfiguration = .default
    private var circuitBreakerConfiguration: CircuitBreakerConfiguration = .default
    private var cacheTTL: TimeInterval = 60
    
    public init() {}
    
    /// Set the file system implementation
    @discardableResult
    public func withFileSystem(_ fileSystem: FileSystemProtocol) -> Self {
        self.fileSystem = fileSystem
        return self
    }
    
    /// Set the parser implementation
    @discardableResult
    public func withParser(_ parser: UsageDataParserProtocol) -> Self {
        self.parser = parser
        return self
    }
    
    /// Set the path decoder implementation
    @discardableResult
    public func withPathDecoder(_ pathDecoder: ProjectPathDecoderProtocol) -> Self {
        self.pathDecoder = pathDecoder
        return self
    }
    
    /// Set the aggregator implementation
    @discardableResult
    public func withAggregator(_ aggregator: StatisticsAggregatorProtocol) -> Self {
        self.aggregator = aggregator
        return self
    }
    
    /// Set the base path
    @discardableResult
    public func withBasePath(_ basePath: String) -> Self {
        self.basePath = basePath
        return self
    }
    
    /// Enable retry mechanism with optional configuration
    @discardableResult
    public func withRetry(configuration: RetryConfiguration = .default) -> Self {
        self.enableRetry = true
        self.retryConfiguration = configuration
        return self
    }
    
    /// Enable circuit breaker with optional configuration
    @discardableResult
    public func withCircuitBreaker(configuration: CircuitBreakerConfiguration = .default) -> Self {
        self.enableCircuitBreaker = true
        self.circuitBreakerConfiguration = configuration
        return self
    }
    
    /// Enable caching with optional TTL
    @discardableResult
    public func withCache(ttl: TimeInterval = 60) -> Self {
        self.enableCache = true
        self.cacheTTL = ttl
        return self
    }
    
    /// Use all default implementations
    @discardableResult
    public func withDefaults() -> Self {
        self.fileSystem = FileSystemService()
        self.parser = JSONLUsageParser()
        self.pathDecoder = ProjectPathDecoder()
        self.aggregator = StatisticsAggregator()
        self.basePath = NSHomeDirectory() + "/.claude"
        return self
    }
    
    /// Use production configuration with all enhancements
    @discardableResult
    public func withProductionConfig() -> Self {
        return withDefaults()
            .withRetry()
            .withCircuitBreaker()
            .withCache(ttl: 300) // 5 minute cache
    }
    
    /// Use test configuration with minimal dependencies
    @discardableResult
    public func withTestConfig() -> Self {
        return withDefaults()
    }
    
    /// Build the repository instance
    public func build() throws -> UsageRepository {
        // Use defaults for any missing dependencies
        var finalFileSystem = fileSystem ?? FileSystemService()
        let finalParser = parser ?? JSONLUsageParser()
        let finalPathDecoder = pathDecoder ?? ProjectPathDecoder()
        let finalAggregator = aggregator ?? StatisticsAggregator()
        let finalBasePath = basePath ?? (NSHomeDirectory() + "/.claude")
        
        // Apply enhancements
        if enableRetry {
            finalFileSystem = RetryableFileSystem(
                fileSystem: finalFileSystem,
                configuration: retryConfiguration
            )
        }
        
        if enableCircuitBreaker {
            finalFileSystem = CircuitBreakerFileSystem(
                fileSystem: finalFileSystem,
                configuration: circuitBreakerConfiguration
            )
        }
        
        let repository = UsageRepository(
            fileSystem: finalFileSystem,
            parser: finalParser,
            pathDecoder: finalPathDecoder,
            aggregator: finalAggregator,
            basePath: finalBasePath
        )
        
        // Wrap with cache if enabled
        if enableCache {
            // Return cached repository wrapper if caching is enabled
            // This would require modifying the return type or creating a protocol
            // For now, return the base repository
            return repository
        }
        
        return repository
    }
    
    /// Build a cached repository instance
    public func buildCached() throws -> CachedUsageRepository {
        let repository = try build()
        return CachedUsageRepository(repository: repository, cacheTTL: cacheTTL)
    }
}

// MARK: - Convenience Factory Methods

public extension UsageRepository {
    /// Create a production-ready repository with all enhancements
    static func production(basePath: String = NSHomeDirectory() + "/.claude") -> UsageRepository {
        do {
            return try UsageRepositoryBuilder()
                .withProductionConfig()
                .withBasePath(basePath)
                .build()
        } catch {
            // Fallback to basic repository if builder fails
            return UsageRepository(basePath: basePath)
        }
    }
    
    /// Create a test repository with minimal dependencies
    static func test(basePath: String = "/tmp/test") -> UsageRepository {
        do {
            return try UsageRepositoryBuilder()
                .withTestConfig()
                .withBasePath(basePath)
                .build()
        } catch {
            // Fallback to basic repository if builder fails
            return UsageRepository(basePath: basePath)
        }
    }
}