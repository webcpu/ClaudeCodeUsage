# Test-Driven Development Guidelines

## TDD Principles for ClaudeCodeUsage

### The Three Laws of TDD

1. **Write a failing test first** - No production code without a failing test
2. **Write minimal code to pass** - Only enough code to make the test green
3. **Refactor** - Clean up while keeping tests green

### Test Structure Pattern

Every test should follow the **Given-When-Then** pattern:

```swift
func test_behaviorDescription_expectedOutcome() {
    // Given (Arrange)
    let dependency = MockDependency()
    let sut = SystemUnderTest(dependency: dependency)
    
    // When (Act)
    let result = sut.performAction()
    
    // Then (Assert)
    XCTAssertEqual(result, expectedValue)
}
```

### Naming Convention

Test names should describe:
- **What** is being tested
- **Under what conditions**
- **What is expected**

```swift
// ✅ GOOD: Descriptive behavior-focused name
func test_loadData_whenNetworkFails_showsErrorState()

// ❌ BAD: Implementation-focused name
func test_loadDataFunction()
```

## TDD Test Template

```swift
import XCTest
import Testing // Swift Testing framework
@testable import ClaudeCodeUsage

// MARK: - Behavior Tests (What the system should do)

@Suite("UserStory: As a user, I want to...")
final class FeatureNameBehaviorTests {
    
    // MARK: - System Under Test
    
    private var sut: FeatureViewModel!
    private var mockService: MockService!
    
    // MARK: - Setup
    
    @Test func setUp() {
        mockService = MockService()
        sut = FeatureViewModel(service: mockService)
    }
    
    // MARK: - Happy Path Tests
    
    @Test("When loading data successfully, should display data")
    func loadingDataSuccess() async {
        // Given
        let expectedData = TestData.sample
        mockService.stubResponse = .success(expectedData)
        
        // When
        await sut.loadData()
        
        // Then
        #expect(sut.data == expectedData)
        #expect(sut.isLoading == false)
        #expect(sut.error == nil)
    }
    
    // MARK: - Error Scenarios
    
    @Test("When network fails, should show error message")
    func networkFailure() async {
        // Given
        let expectedError = NetworkError.connectionFailed
        mockService.stubResponse = .failure(expectedError)
        
        // When
        await sut.loadData()
        
        // Then
        #expect(sut.data == nil)
        #expect(sut.error?.localizedDescription == "Connection failed")
        #expect(sut.isLoading == false)
    }
    
    // MARK: - Edge Cases
    
    @Test("When data is empty, should show empty state")
    func emptyDataHandling() async {
        // Given
        mockService.stubResponse = .success([])
        
        // When
        await sut.loadData()
        
        // Then
        #expect(sut.isEmpty == true)
        #expect(sut.emptyMessage == "No data available")
    }
    
    // MARK: - Business Rules
    
    @Test("When cost exceeds budget, should show warning")
    func budgetExceededWarning() {
        // Given
        sut.budget = 100.0
        
        // When
        sut.updateCost(150.0)
        
        // Then
        #expect(sut.showsBudgetWarning == true)
        #expect(sut.warningMessage == "Budget exceeded by $50.00")
    }
}

// MARK: - Mock Infrastructure

final class MockService: ServiceProtocol {
    var stubResponse: Result<Data, Error>?
    var capturedParameters: [Any] = []
    var callCount = 0
    
    func fetchData() async throws -> Data {
        callCount += 1
        switch stubResponse {
        case .success(let data):
            return data
        case .failure(let error):
            throw error
        case .none:
            throw TestError.notStubbed
        }
    }
}
```

## TDD Process Example

### Step 1: Write Failing Test (RED)
```swift
@Test("Today's cost should sum all entries for current date")
func calculateTodaysCost() {
    // This test will fail because the feature doesn't exist yet
    let sut = CostCalculator()
    let entries = [
        UsageEntry(date: Date(), cost: 10.0),
        UsageEntry(date: Date(), cost: 15.0),
        UsageEntry(date: Date().addingDays(-1), cost: 20.0) // Yesterday
    ]
    
    let todaysCost = sut.calculateTodaysCost(from: entries)
    
    #expect(todaysCost == 25.0) // Only today's entries
}
```

### Step 2: Write Minimal Code (GREEN)
```swift
struct CostCalculator {
    func calculateTodaysCost(from entries: [UsageEntry]) -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return entries
            .filter { calendar.startOfDay(for: $0.date) == today }
            .reduce(0) { $0 + $1.cost }
    }
}
```

### Step 3: Refactor
```swift
struct CostCalculator {
    private let calendar = Calendar.current
    
    func calculateTodaysCost(from entries: [UsageEntry]) -> Double {
        calculateCost(from: entries, for: Date())
    }
    
    func calculateCost(from entries: [UsageEntry], for date: Date) -> Double {
        let targetDate = calendar.startOfDay(for: date)
        
        return entries
            .filter { calendar.startOfDay(for: $0.date) == targetDate }
            .map(\.cost)
            .reduce(0, +)
    }
}
```

## Test Categories

### 1. Unit Tests (Fast, Isolated)
- Test single units in isolation
- Use mocks for all dependencies
- Should run in milliseconds
- Located in: `Tests/Unit/`

### 2. Integration Tests (Slower, Real Dependencies)
- Test interaction between components
- Use real implementations where appropriate
- May access file system or network
- Located in: `Tests/Integration/`

### 3. UI Tests (Slowest, End-to-End)
- Test complete user workflows
- Use real UI interactions
- Verify business value delivery
- Located in: `Tests/UI/`

## Red Flags (Anti-Patterns)

### ❌ Testing Implementation
```swift
// BAD: Tests private implementation details
func testArrayCount() {
    XCTAssertEqual(viewModel.internalArray.count, 5)
}
```

### ❌ Multiple Assertions
```swift
// BAD: Tests multiple behaviors
func testEverything() {
    XCTAssertNotNil(result)
    XCTAssertEqual(result.count, 10)
    XCTAssertTrue(result.isValid)
    XCTAssertEqual(result.total, 100)
}
```

### ❌ Logic in Tests
```swift
// BAD: Complex logic in test
func testCalculation() {
    let expected = inputs.map { $0 * 2 }.reduce(0, +) // Logic in test!
    XCTAssertEqual(result, expected)
}
```

### ❌ Shared State
```swift
// BAD: Tests depend on each other
class BadTests {
    static var sharedData: Data? // Shared state!
    
    func test1() {
        Self.sharedData = Data()
    }
    
    func test2() {
        XCTAssertNotNil(Self.sharedData) // Depends on test1!
    }
}
```

## TDD Checklist

Before writing code, ask:
- [ ] Do I have a failing test?
- [ ] Does the test name describe behavior?
- [ ] Is the test testing one thing?
- [ ] Will this test be fast?
- [ ] Is the test independent?

After writing code, ask:
- [ ] Does the test pass?
- [ ] Is this the minimal code needed?
- [ ] Can I refactor while keeping tests green?
- [ ] Do I need another test for edge cases?
- [ ] Is the code self-documenting through tests?

## Coverage Goals

### Minimum Coverage Requirements
- **ViewModels**: 90% coverage
- **Business Logic**: 95% coverage
- **Utilities**: 85% coverage
- **UI Components**: 70% coverage

### What to Test
- ✅ Public API behavior
- ✅ Business rules and logic
- ✅ Error scenarios
- ✅ Edge cases and boundaries
- ✅ State transitions

### What NOT to Test
- ❌ Private implementation details
- ❌ Third-party framework behavior
- ❌ Simple getters/setters
- ❌ UI layout specifics
- ❌ Temporary debugging code