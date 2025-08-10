# LiveMonitor Actor Migration Plan

## Current State

LiveMonitor currently uses GCD (Grand Central Dispatch) with a concurrent queue and barriers for thread safety. While this works, it doesn't align with the project's architectural principles of using "Actor-Based Concurrency" as stated in CLAUDE.md.

## Issues with Current Implementation

1. **Architectural Inconsistency**: Rest of codebase uses modern Swift concurrency (actors, async/await)
2. **Complexity**: Developers must understand queue semantics and barrier flags
3. **Testing Difficulty**: GCD makes unit testing more complex
4. **Performance**: Unnecessary synchronization overhead in some operations

## Proposed Actor-Based Solution

### Step 1: Convert LiveMonitor to Actor

```swift
public actor LiveMonitor {
    private let config: LiveMonitorConfig
    private var lastFileTimestamps: [String: Date] = [:]
    private var processedHashes: Set<String> = Set()
    private var allEntries: [UsageEntry] = []
    private var maxTokensFromPreviousSessions: Int = 0
    private nonisolated let parser = JSONLParser()
    
    public init(config: LiveMonitorConfig) {
        self.config = config
    }
    
    public func getActiveBlock() -> SessionBlock? {
        // Direct access to properties - actor ensures thread safety
        let files = findUsageFiles()
        
        if files.isEmpty {
            return nil
        }
        
        // Check for new or modified files
        var filesToRead: [String] = []
        for file in files {
            if let timestamp = getFileModificationTime(file) {
                let lastTimestamp = lastFileTimestamps[file]
                if lastTimestamp == nil || timestamp > lastTimestamp! {
                    filesToRead.append(file)
                    lastFileTimestamps[file] = timestamp
                }
            }
        }
        
        // Rest of implementation...
    }
    
    public func clearCache() {
        // Simple, synchronous within actor context
        lastFileTimestamps.removeAll()
        processedHashes.removeAll()
        allEntries.removeAll()
        maxTokensFromPreviousSessions = 0
    }
}
```

### Step 2: Update Callers

```swift
// Before (synchronous)
let activeBlock = liveMonitor.getActiveBlock()

// After (async)
let activeBlock = await liveMonitor.getActiveBlock()
```

### Step 3: Update DefaultSessionMonitorService

```swift
final class DefaultSessionMonitorService: SessionMonitorService {
    private let liveMonitor: LiveMonitor
    
    func getActiveSession() async -> SessionBlock? {
        return await liveMonitor.getActiveBlock()
    }
    
    func getBurnRate() async -> BurnRate? {
        guard let session = await getActiveSession() else { return nil }
        // Calculate burn rate...
    }
}
```

### Step 4: Update Protocol

```swift
protocol SessionMonitorService {
    func getActiveSession() async -> SessionBlock?
    func getBurnRate() async -> BurnRate?
    func getAutoTokenLimit() async -> Int?
}
```

## Benefits of Actor Migration

### 1. Simplified Code
- No queue management
- No barrier flags to remember
- Automatic thread safety

### 2. Better Performance
- Swift runtime optimizations for actors
- Reduced context switching
- Better cache locality

### 3. Improved Testing
```swift
@MainActor
final class LiveMonitorTests: XCTestCase {
    func testGetActiveBlock() async {
        let monitor = LiveMonitor(config: testConfig)
        let block = await monitor.getActiveBlock()
        XCTAssertNotNil(block)
    }
}
```

### 4. Future-Proof
- Aligns with Swift evolution
- Better IDE support
- Improved debugging experience

## Migration Strategy

### Phase 1: Parallel Implementation (1 week)
- Create `LiveMonitorActor` alongside existing `LiveMonitor`
- Implement full functionality with actors
- Write comprehensive tests

### Phase 2: A/B Testing (1 week)
- Use feature flag to switch between implementations
- Monitor performance metrics
- Gather crash reports

### Phase 3: Gradual Rollout (2 weeks)
- Start with 10% of users
- Monitor for issues
- Increase to 50%, then 100%

### Phase 4: Cleanup (1 week)
- Remove old GCD implementation
- Update documentation
- Archive migration notes

## Risk Assessment

### Low Risk
- Actor model is stable in Swift 5.5+
- Compile-time safety for data races
- Easy rollback strategy

### Mitigation
- Keep GCD version for fallback
- Comprehensive testing before migration
- Gradual rollout with monitoring

## Estimated Timeline

- **Research & Design**: 2 days
- **Implementation**: 3 days
- **Testing**: 2 days
- **Code Review**: 1 day
- **Rollout**: 2 weeks
- **Total**: ~3 weeks

## Success Metrics

1. **No increase in crash rate**
2. **Performance improvement of 10-20%**
3. **Reduced code complexity (LOC -30%)**
4. **Improved test coverage (+20%)**
5. **Zero concurrency-related bugs**

## Conclusion

Migrating LiveMonitor to use Swift actors aligns with the project's architectural principles, simplifies the codebase, and provides better performance and safety guarantees. The migration can be done incrementally with minimal risk.