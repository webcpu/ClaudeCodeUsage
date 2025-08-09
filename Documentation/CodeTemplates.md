# Code Templates for ClaudeCodeUsage

## ViewModel Templates

### Standard ViewModel Template

Use this template when creating new ViewModels:

```swift
//
//  ___FILENAME___
//  ___PROJECTNAME___
//
//  Created by ___FULLUSERNAME___ on ___DATE___
//

import SwiftUI
import Observation

// MARK: - ___FILEBASENAMEASIDENTIFIER___

/// ViewModel for managing ___PURPOSE___
///
/// This ViewModel follows the @Observable pattern for fine-grained
/// state updates and better performance than ObservableObject.
@Observable
@MainActor
final class ___FILEBASENAMEASIDENTIFIER___ {
    
    // MARK: - Observable State
    
    /// Primary data being managed
    var data: DataType?
    
    /// Loading state for async operations
    var isLoading = false
    
    /// Error state for user feedback
    var error: Error?
    
    // MARK: - Private Properties
    
    /// Dependencies injected via initializer
    private let service: ServiceProtocol
    
    /// Task handle for cancellation
    private var loadTask: Task<Void, Never>?
    
    // MARK: - Computed Properties
    
    /// Derived state computed from observable properties
    var derivedValue: String {
        // Computed properties automatically participate in observation
        return data?.description ?? "No data"
    }
    
    // MARK: - Initialization
    
    /// Initialize with required dependencies
    /// - Parameter service: Service for data operations
    init(service: ServiceProtocol = ServiceImplementation()) {
        self.service = service
    }
    
    deinit {
        loadTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Load data asynchronously
    func loadData() async {
        // Cancel any existing load operation
        loadTask?.cancel()
        
        // Create new load task
        loadTask = Task { @MainActor in
            isLoading = true
            error = nil
            
            do {
                data = try await service.fetchData()
            } catch {
                self.error = error
            }
            
            isLoading = false
        }
        
        await loadTask?.value
    }
    
    /// Handle user actions
    func handleAction(_ action: Action) {
        switch action {
        case .refresh:
            Task { await loadData() }
        case .clear:
            data = nil
            error = nil
        }
    }
}

// MARK: - Supporting Types

extension ___FILEBASENAMEASIDENTIFIER___ {
    enum Action {
        case refresh
        case clear
    }
}
```

### Simplified ViewModel Template (No Async)

For simpler ViewModels without async operations:

```swift
import SwiftUI
import Observation

@Observable
@MainActor
final class ___FILEBASENAMEASIDENTIFIER___ {
    
    // MARK: - Observable State
    var items: [Item] = []
    var selectedItem: Item?
    var searchText = ""
    
    // MARK: - Computed Properties
    var filteredItems: [Item] {
        guard !searchText.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var hasSelection: Bool {
        selectedItem != nil
    }
    
    // MARK: - Public Methods
    func selectItem(_ item: Item) {
        selectedItem = item
    }
    
    func clearSelection() {
        selectedItem = nil
    }
    
    func addItem(_ item: Item) {
        items.append(item)
    }
    
    func removeItem(_ item: Item) {
        items.removeAll { $0.id == item.id }
    }
}
```

## View Templates

### View Using @Observable ViewModel

```swift
import SwiftUI

struct ___FILEBASENAMEASIDENTIFIER___: View {
    
    // Use @State for owned ViewModels
    @State private var viewModel = ___VIEWMODEL___()
    
    // Or receive from environment/parent
    let viewModel: ___VIEWMODEL___
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.error {
                ErrorView(error: error) {
                    Task { await viewModel.loadData() }
                }
            } else {
                ContentView(data: viewModel.data)
            }
        }
        .task {
            await viewModel.loadData()
        }
    }
}
```

### View with Environment ViewModel

```swift
import SwiftUI

struct ___FILEBASENAMEASIDENTIFIER___: View {
    
    // Access shared ViewModel from environment
    @Environment(AppViewModel.self) private var appViewModel
    
    var body: some View {
        @Bindable var appViewModel = appViewModel
        
        VStack {
            TextField("Search", text: $appViewModel.searchText)
            
            List(appViewModel.filteredItems) { item in
                ItemRow(item: item)
                    .onTapGesture {
                        appViewModel.selectItem(item)
                    }
            }
        }
    }
}
```

## Xcode Code Snippets

### Install Code Snippets

1. Open Xcode
2. Select text of template
3. Right-click → Create Code Snippet
4. Set completion shortcut:
   - `viewmodel` - Creates Observable ViewModel
   - `observablevm` - Creates full ViewModel template
   - `mainactorvm` - Creates @MainActor ViewModel

### Snippet 1: Observable ViewModel

**Title:** Observable ViewModel
**Platform:** All
**Language:** Swift
**Completion:** `viewmodel`

```swift
@Observable
@MainActor
final class <#ViewModelName#> {
    
    // MARK: - Observable State
    var <#property#>: <#Type#>
    
    // MARK: - Public Methods
    func <#methodName#>() {
        <#code#>
    }
}
```

### Snippet 2: Observable Property

**Title:** Observable Property
**Platform:** All
**Language:** Swift
**Completion:** `obsprop`

```swift
/// <#Description#>
var <#propertyName#>: <#Type#> = <#defaultValue#>
```

### Snippet 3: Computed Observable Property

**Title:** Computed Observable Property
**Platform:** All
**Language:** Swift
**Completion:** `obscomputed`

```swift
/// <#Description#>
var <#propertyName#>: <#Type#> {
    <#computation#>
}
```

## VS Code Snippets

Add to `.vscode/swift.code-snippets`:

```json
{
  "Observable ViewModel": {
    "prefix": "viewmodel",
    "body": [
      "import SwiftUI",
      "import Observation",
      "",
      "@Observable",
      "@MainActor",
      "final class ${1:ViewModelName} {",
      "    ",
      "    // MARK: - Observable State",
      "    var ${2:property}: ${3:Type}",
      "    ",
      "    // MARK: - Public Methods",
      "    func ${4:methodName}() {",
      "        ${5:// Implementation}",
      "    }",
      "}"
    ],
    "description": "Create an Observable ViewModel with MainActor"
  },
  
  "Observable State Property": {
    "prefix": "obsprop",
    "body": [
      "/// ${1:Description}",
      "var ${2:propertyName}: ${3:Type} = ${4:defaultValue}"
    ],
    "description": "Create an observable state property"
  }
}
```

## Best Practices Checklist

### ✅ DO:
- Always use `@Observable` for ViewModels
- Always add `@MainActor` to ViewModels for thread safety
- Use `@State` for owned ViewModels in Views
- Use computed properties for derived state
- Import `Observation` in ViewModel files
- Cancel async tasks in deinit

### ❌ DON'T:
- Use `ObservableObject` for new ViewModels
- Use `@Published` properties
- Use `@StateObject` in Views
- Use `@ObservedObject` with Observable types
- Import Combine unless needed for system APIs
- Create observation cycles with circular references

## Migration Checklist

When converting existing ViewModels:

1. [ ] Replace `ObservableObject` with `@Observable`
2. [ ] Add `@MainActor` annotation
3. [ ] Remove all `@Published` wrappers
4. [ ] Change `import Combine` to `import Observation`
5. [ ] Remove `cancellables` and Combine subscriptions
6. [ ] Update Views: `@StateObject` → `@State`
7. [ ] Update Views: Remove `@ObservedObject`
8. [ ] Test that all bindings still work
9. [ ] Verify no observation cycles exist
10. [ ] Run SwiftLint to check compliance