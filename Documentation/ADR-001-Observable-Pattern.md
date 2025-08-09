# ADR-001: Adopt @Observable Macro for ViewModels

## Status
**Accepted** - Implemented August 2025

## Context

The ClaudeCodeUsage project initially used the traditional `ObservableObject` protocol with `@Published` properties for state management in ViewModels. This pattern, while functional, has several limitations:

1. **Performance overhead**: ObservableObject triggers view updates for ANY property change
2. **Boilerplate code**: Requires @Published wrappers, manual Combine subscriptions, and cancellables management
3. **Complex bindings**: Multi-level property observation requires manual Combine chains
4. **Memory management**: Need to manage AnyCancellable collections

Swift 5.9 introduced the `@Observable` macro as part of the Observation framework, offering a modern alternative with significant advantages.

## Decision

We have decided to **adopt the @Observable macro pattern** for all ViewModels in the ClaudeCodeUsage project, combined with @MainActor for thread safety.

### Standard Pattern

```swift
import Observation
import SwiftUI

@Observable
@MainActor
final class ViewModelName {
    // Properties are automatically observable
    var property: Type
    
    // Computed properties participate in observation
    var computed: Type { 
        // Derives from observable properties
    }
}
```

## Consequences

### Positive Consequences

1. **Better Performance**
   - Fine-grained updates: Only views using changed properties re-render
   - Automatic dependency tracking by Swift compiler
   - Reduced overhead compared to Combine publishers

2. **Cleaner Code**
   - Eliminated ~100 lines of boilerplate in existing ViewModels
   - No @Published property wrappers needed
   - No manual Combine subscription management
   - Direct property access without binding chains

3. **Improved Developer Experience**
   - Simpler mental model
   - Less error-prone (no forgotten @Published)
   - Better autocomplete and type inference
   - Easier testing without Combine complexity

4. **Future-Proof Architecture**
   - Aligned with Swift's evolution direction
   - Apple's recommended pattern for new SwiftUI apps
   - Better integration with SwiftUI's reactive system

### Negative Consequences

1. **iOS 17+ Requirement**
   - Requires iOS 17.0+ / macOS 14.0+
   - Not suitable for apps needing older OS support

2. **Migration Effort**
   - Existing ViewModels need refactoring
   - Team needs to learn new patterns
   - Documentation and examples need updating

3. **Tool Support**
   - Some third-party tools may not fully support @Observable yet
   - Debugging tools still evolving

## Implementation

### Migration Steps Completed

1. ✅ Converted all ViewModels to @Observable
2. ✅ Added @MainActor for thread safety
3. ✅ Replaced @StateObject with @State in Views
4. ✅ Removed @ObservedObject usage
5. ✅ Eliminated Combine dependencies where not needed
6. ✅ Updated all tests to work with new pattern

### Enforcement Mechanisms

1. **SwiftLint Rules** (`.swiftlint.yml`)
   - Custom rules to prohibit ObservableObject in ViewModels
   - Warnings for @Published usage
   - Enforcement of @MainActor with @Observable

2. **Code Templates** (`Documentation/CodeTemplates.md`)
   - Standard ViewModel templates
   - Xcode and VS Code snippets
   - Migration checklists

3. **Documentation** (`CLAUDE.md`)
   - Clear architectural guidelines
   - Examples of correct/incorrect patterns
   - Benefits and rationale

4. **Code Review**
   - Ensure new ViewModels follow @Observable pattern
   - Check for proper @MainActor usage
   - Verify no ObservableObject usage

## Alternatives Considered

### 1. Keep ObservableObject Pattern
- **Pros**: No migration needed, wider OS compatibility
- **Cons**: Performance limitations, more boilerplate
- **Rejected**: Technical debt would increase over time

### 2. Custom Observation System
- **Pros**: Full control over implementation
- **Cons**: Significant development effort, maintenance burden
- **Rejected**: Reinventing what Swift provides natively

### 3. Reactive Framework (RxSwift/ReactiveSwift)
- **Pros**: Powerful reactive capabilities
- **Cons**: Heavy dependency, steep learning curve
- **Rejected**: Overkill for our needs, adds complexity

## Metrics for Success

1. **Code Reduction**: ~30% less boilerplate in ViewModels
2. **Performance**: Measurable reduction in unnecessary view updates
3. **Developer Velocity**: Faster feature development with less boilerplate
4. **Bug Reduction**: Fewer state management related bugs

## References

- [Swift Evolution Proposal SE-0395: Observation](https://github.com/apple/swift-evolution/blob/main/proposals/0395-observability.md)
- [WWDC23: Discover Observation in SwiftUI](https://developer.apple.com/videos/play/wwdc2023/10149/)
- [Apple Documentation: Observation Framework](https://developer.apple.com/documentation/observation)

## Review History

- **2025-08-09**: Initial implementation and documentation
- **2025-08-09**: SwiftLint rules added for enforcement
- **2025-08-09**: All ViewModels successfully migrated

## Appendix: Example Migration

### Before (ObservableObject)
```swift
import Combine
import SwiftUI

class UsageViewModel: ObservableObject {
    @Published var stats: UsageStats?
    @Published var isLoading = false
    private var cancellables = Set<AnyCancellable>()
    
    init(service: Service) {
        service.statsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stats in
                self?.stats = stats
            }
            .store(in: &cancellables)
    }
}

struct UsageView: View {
    @StateObject private var viewModel = UsageViewModel()
}
```

### After (@Observable)
```swift
import Observation
import SwiftUI

@Observable
@MainActor
final class UsageViewModel {
    var stats: UsageStats?
    var isLoading = false
    
    init(service: Service) {
        // Direct property assignment, no Combine needed
    }
}

struct UsageView: View {
    @State private var viewModel = UsageViewModel()
}
```

This architectural decision significantly improves code quality, performance, and developer experience while positioning the project for long-term maintainability.