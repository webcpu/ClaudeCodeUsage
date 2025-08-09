# Test Plan - ClaudeCodeUsage

## Test Organization Structure

```
Tests/
├── Unit/                           # Fast, isolated tests
│   ├── ViewModels/
│   │   ├── UsageViewModelTests.swift
│   │   ├── HeatmapViewModelTests.swift
│   │   └── ChartViewModelTests.swift
│   ├── Services/
│   │   ├── CostCalculationTests.swift
│   │   ├── DeduplicationTests.swift
│   │   └── FilterServiceTests.swift
│   ├── Models/
│   │   ├── UsageEntryTests.swift
│   │   ├── UsageStatsTests.swift
│   │   └── ConfigurationTests.swift
│   └── Utilities/
│       ├── DateCalculationsTests.swift
│       ├── ColorSchemeTests.swift
│       └── FormatterTests.swift
│
├── Integration/                    # Tests with real dependencies
│   ├── RepositoryTests.swift
│   ├── FileSystemTests.swift
│   ├── ParserIntegrationTests.swift
│   └── LiveMonitorTests.swift
│
├── UI/                            # UI behavior tests
│   ├── MenuBarTests.swift
│   ├── HeatmapInteractionTests.swift
│   └── ChartInteractionTests.swift
│
├── Performance/                   # Performance benchmarks
│   ├── LargeDatasetTests.swift
│   ├── HoverPerformanceTests.swift
│   └── MemoryLeakTests.swift
│
└── Fixtures/                      # Test data
    ├── MockData.swift
    ├── TestHelpers.swift
    └── SampleFiles/
        ├── valid_usage.json
        ├── corrupt_usage.json
        └── large_dataset.json
```

## Current Test Coverage Analysis

### ✅ Well-Tested Components (>80% coverage)
- SOLIDRefactoringTests
- UsageViewModelTests (partial)
- HourlyCostChartTests

### ⚠️ Partially Tested (30-80% coverage)
- Repository layer
- Parser components
- Basic models

### ❌ Critical Gaps (0-30% coverage)
1. **ViewModels** (40+ untested)
   - HeatmapViewModel ❌
   - ChartDataService ❌
   - SessionViewModel ❌
   
2. **Services**
   - ConfigurationService ❌
   - SessionMonitorService ❌
   - AppLifecycleManager ❌
   
3. **Error Scenarios**
   - Network failures ❌
   - File corruption ❌
   - Permission errors ❌
   - Memory pressure ❌

## TDD Test Suite Requirements

### 1. Behavioral Test Categories

#### User Stories to Test
```swift
// Format: "As a [user], I want to [action] so that [benefit]"

"As a user, I want to see my daily costs so that I can track spending"
"As a user, I want to see hourly breakdown so that I can identify peak usage"
"As a user, I want to see a yearly heatmap so that I can spot usage patterns"
"As a user, I want real-time updates so that I see current session costs"
"As a user, I want to export data so that I can analyze it externally"
```

#### Error Scenarios (Red Path Testing)
```swift
// Each component should handle these gracefully

1. File System Errors
   - File not found
   - Permission denied
   - Disk full
   - Corrupt JSON

2. Data Errors
   - Invalid dates
   - Negative costs
   - Missing required fields
   - Overflow values

3. System Errors
   - Memory pressure
   - Network timeout
   - Process interruption
   - Configuration missing

4. User Errors
   - Invalid input
   - Conflicting settings
   - Rapid interactions
   - Edge case inputs
```

### 2. Missing Critical Tests

#### A. Cost Calculation Edge Cases
```swift
@Test("Should handle cost overflow gracefully")
func handlesCostOverflow() {
    // When: Cost exceeds Double.max
    // Then: Should cap at maximum displayable value
}

@Test("Should handle negative costs as zero")
func handlesNegativeCosts() {
    // When: API returns negative cost
    // Then: Should treat as 0
}

@Test("Should round micro-costs correctly")
func roundsMicroCosts() {
    // When: Cost is 0.0000001
    // Then: Should display as $0.00
}
```

#### B. Date Boundary Tests
```swift
@Test("Should handle daylight saving transitions")
func handlesDSTTransition() {
    // When: Data spans DST change
    // Then: Should maintain correct hourly grouping
}

@Test("Should handle leap year correctly")
func handlesLeapYear() {
    // When: February 29th data exists
    // Then: Should display correctly in heatmap
}

@Test("Should handle timezone changes")
func handlesTimezoneChange() {
    // When: User changes timezone
    // Then: Should recalculate daily boundaries
}
```

#### C. Concurrency Tests
```swift
@Test("Should handle concurrent data updates")
func handlesConcurrentUpdates() {
    // When: Multiple updates arrive simultaneously
    // Then: Should maintain data consistency
}

@Test("Should cancel previous loads")
func cancelsPreviousLoads() {
    // When: New load requested before previous completes
    // Then: Should cancel previous and use latest
}
```

#### D. Memory Management Tests
```swift
@Test("Should not retain references after view dismissal")
func avoidsRetainCycles() {
    // When: View is dismissed
    // Then: ViewModel should be deallocated
}

@Test("Should handle memory warnings")
func handlesMemoryWarning() {
    // When: System sends memory warning
    // Then: Should clear caches
}
```

### 3. Test Doubles Strategy

#### Mock vs Stub vs Fake
```swift
// Mock: Verifies interactions
class MockRepository {
    var loadCalled = false
    var loadCallCount = 0
    
    func load() {
        loadCalled = true
        loadCallCount += 1
    }
}

// Stub: Provides canned responses
class StubRepository {
    var stubData: [Entry] = []
    
    func load() -> [Entry] {
        return stubData
    }
}

// Fake: Simplified working implementation
class FakeRepository {
    private var storage: [Entry] = []
    
    func save(_ entry: Entry) {
        storage.append(entry)
    }
    
    func load() -> [Entry] {
        return storage
    }
}
```

### 4. TDD Workflow for New Features

#### Example: Adding Export Feature

##### Step 1: Write Failing Test
```swift
@Test("Should export data as CSV")
func exportsAsCSV() {
    // Given
    let viewModel = ExportViewModel()
    let data = [Entry(date: "2025-01-01", cost: 10.0)]
    
    // When
    let csv = viewModel.exportAsCSV(data)
    
    // Then
    #expect(csv == "Date,Cost\n2025-01-01,10.00")
}
```

##### Step 2: Minimal Implementation
```swift
struct ExportViewModel {
    func exportAsCSV(_ entries: [Entry]) -> String {
        var csv = "Date,Cost\n"
        for entry in entries {
            csv += "\(entry.date),\(String(format: "%.2f", entry.cost))\n"
        }
        return csv
    }
}
```

##### Step 3: Add Edge Case Tests
```swift
@Test("Should handle empty data")
func exportsEmptyData() {
    #expect(viewModel.exportAsCSV([]) == "Date,Cost\n")
}

@Test("Should escape commas in data")
func escapesCommas() {
    let entry = Entry(date: "2025-01-01", cost: 1000.00)
    #expect(viewModel.exportAsCSV([entry]).contains("\"1,000.00\""))
}
```

### 5. Test Quality Metrics

#### Coverage Goals by Component Type
- **Business Logic**: 95% minimum
- **ViewModels**: 90% minimum
- **Utilities**: 85% minimum
- **UI Components**: 70% minimum
- **Integration Points**: 80% minimum

#### Test Speed Requirements
- **Unit Tests**: < 10ms per test
- **Integration Tests**: < 100ms per test
- **UI Tests**: < 1s per test
- **Full Suite**: < 30 seconds

#### Test Reliability
- **Flakiness**: 0% tolerance
- **Isolation**: No shared state
- **Repeatability**: Same result every run
- **Independence**: Order doesn't matter

### 6. Continuous Testing Strategy

#### Pre-commit Hooks
```bash
#!/bin/sh
# .git/hooks/pre-commit

# Run fast unit tests
swift test --filter Unit

# Check coverage
xcrun llvm-cov report
```

#### CI Pipeline
```yaml
name: Test Suite
on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - name: Unit Tests
        run: swift test --filter Unit
        
      - name: Integration Tests
        run: swift test --filter Integration
        
      - name: Coverage Report
        run: |
          swift test --enable-code-coverage
          xcrun llvm-cov report
```

### 7. Test Data Management

#### Fixture Builder Pattern
```swift
struct TestDataBuilder {
    private var entry = UsageEntry.default
    
    func withDate(_ date: Date) -> TestDataBuilder {
        var builder = self
        builder.entry.date = date
        return builder
    }
    
    func withCost(_ cost: Double) -> TestDataBuilder {
        var builder = self
        builder.entry.cost = cost
        return builder
    }
    
    func build() -> UsageEntry {
        return entry
    }
}

// Usage
let entry = TestDataBuilder()
    .withDate(Date())
    .withCost(10.0)
    .build()
```

## Action Items

### Immediate (This Sprint)
1. ✅ Create TDD-compliant tests for HeatmapViewModel
2. ✅ Rewrite HourlyCostChartTests following TDD
3. ⬜ Add error scenario tests for all ViewModels
4. ⬜ Separate unit and integration tests

### Next Sprint
1. ⬜ Add performance test suite
2. ⬜ Create UI interaction tests
3. ⬜ Implement test data builders
4. ⬜ Add mutation testing

### Future
1. ⬜ Contract testing for API boundaries
2. ⬜ Snapshot testing for UI components
3. ⬜ Property-based testing for algorithms
4. ⬜ Load testing for large datasets