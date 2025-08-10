# Typed Throws Migration Guide

## Status: Pending (Requires Swift 6.0+)

### Current State
- **Swift Version**: 5.9 (typed throws requires 6.0+)
- **Error Handling**: Generic `throws` without type information
- **Error Types**: Well-defined (FileSystemError, RepositoryError, etc.)

### Prerequisites
1. Update to Swift 6.0+ when stable
2. Ensure all dependencies support Swift 6.0
3. Update CI/CD pipeline for Swift 6.0

### Migration Plan

#### Phase 1: Update Swift Version
```swift
// Package.swift
// swift-tools-version: 6.0
```

#### Phase 2: High-Priority Targets
These protocols/functions have clear single-error boundaries:

1. **FileSystemProtocol** (FileSystemError only)
   ```swift
   // Before
   func readFile(atPath path: String) throws -> String
   
   // After
   func readFile(atPath path: String) throws(FileSystemError) -> String
   ```

2. **AsyncFileSystemProtocol** (FileSystemError only)
   ```swift
   // Before
   func readFile(atPath path: String) async throws -> String
   
   // After  
   func readFile(atPath path: String) async throws(FileSystemError) -> String
   ```

3. **UsageRepositoryProtocol** (RepositoryError only)
   ```swift
   // Before
   func loadEntriesForDate(_ date: Date) async throws -> [UsageEntry]
   
   // After
   func loadEntriesForDate(_ date: Date) async throws(RepositoryError) -> [UsageEntry]
   ```

#### Phase 3: Medium-Priority Targets
Functions with limited error types:

- HeatmapViewModel validation (HeatmapError)
- Parser protocols (ParsingError)
- Cache operations (CacheError)

#### Phase 4: Complex Cases
Functions that throw multiple error types:

```swift
// Option 1: Composite Error
enum DataOperationError: Error {
    case fileSystem(FileSystemError)
    case parsing(ParsingError)
    case repository(RepositoryError)
}

func loadAndParse() async throws(DataOperationError) -> Data

// Option 2: Keep generic for truly polymorphic
func retry<T>(_ operation: () async throws -> T) async throws -> T
```

### Benefits
1. **Compile-time safety** - Know exactly what errors to handle
2. **Better IntelliSense** - IDE shows possible errors
3. **Cleaner tests** - Test specific error cases
4. **Documentation** - Self-documenting error contracts

### Testing Strategy
```swift
// With typed throws
@Test
func testFileNotFound() async {
    do {
        _ = try await repository.loadFile("nonexistent")
        Issue.record("Should have thrown FileSystemError")
    } catch FileSystemError.fileNotFound {
        // Expected
    }
    // Compiler ensures no other errors possible
}
```

### Backward Compatibility
- Keep generic throws for public API initially
- Use typed throws internally first
- Gradually migrate public API with deprecation warnings

### Timeline
- [ ] Wait for Swift 6.0 stable release
- [ ] Test in development branch
- [ ] Gradual rollout starting with internal APIs
- [ ] Full migration with major version bump

### Alternative for Swift 5.9
Until we can use typed throws, improve error handling with:

```swift
// Use Result type for explicit errors
func readFile(atPath path: String) -> Result<String, FileSystemError>

// Document thrown errors
/// - Throws: `FileSystemError.fileNotFound` if file doesn't exist
func processFile(atPath path: String) throws -> Data
```