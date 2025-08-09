# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ClaudeCodeUsage is a Swift SDK and application suite for analyzing Claude Code usage data from the Claude desktop application. It reads data from `~/.claude/projects/` and provides analytics, cost tracking, and real-time monitoring.

## Build & Development Commands

### Building and Running
```bash
# Build all targets
swift build

# Run the macOS menu bar app
swift run UsageDashboardApp

# Run the CLI dashboard
swift run UsageDashboardCLI

# Run simple CLI example
swift run SimpleCLI

# Build for release
swift build -c release
```

### Testing
```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter ClaudeCodeUsageTests

# Run a single test
swift test --filter "TestClassName/testMethodName"
```

## Critical: ViewModel Architecture Standards ⚠️

### ALWAYS Use @Observable + @MainActor for ViewModels

**This project uses Swift's modern `@Observable` macro. DO NOT use `ObservableObject` or `@Published` patterns.**

#### ✅ Correct ViewModel Pattern
```swift
import SwiftUI
import Observation

@Observable
@MainActor
final class ExampleViewModel {
    var data: DataType?
    var isLoading = false
    
    func loadData() async {
        // Implementation
    }
}
```

#### ❌ NEVER Use This Pattern
```swift
import Combine

class ExampleViewModel: ObservableObject {  // ❌ DON'T use ObservableObject
    @Published var data: DataType?          // ❌ DON'T use @Published
    @Published var isLoading = false        // ❌ DON'T use @Published
}
```

#### View Integration
```swift
// ✅ CORRECT: Use @State with @Observable ViewModels
struct ExampleView: View {
    @State private var viewModel = ExampleViewModel()
}

// ❌ WRONG: Don't use @StateObject or @ObservedObject
struct BadView: View {
    @StateObject private var viewModel = ExampleViewModel()  // ❌
}
```

### Enforcement Rules
1. **ALWAYS** use `@Observable` macro for ViewModels
2. **ALWAYS** use `@MainActor` with ViewModels
3. **NEVER** use `ObservableObject` protocol
4. **NEVER** use `@Published` properties
5. **NEVER** use `@StateObject` or `@ObservedObject`
6. Import `Observation` not `Combine` for ViewModels

## Architecture Overview

### Package Structure
The project uses Swift Package Manager with multiple targets:
- **ClaudeCodeUsage**: Core SDK library with clean architecture
- **UsageDashboardApp**: SwiftUI macOS menu bar application  
- **UsageDashboardCLI**: Command-line dashboard interface
- **SimpleCLI**: Basic CLI usage example

### Core Design Patterns
1. **Repository Pattern**: `UsageRepository` abstracts data access with protocol-based design
2. **Dependency Injection**: `DependencyContainer` protocol enables testing with mock implementations
3. **Actor-Based Concurrency**: Thread-safe state management using Swift actors
4. **MVVM with @Observable**: Modern ViewModels using `@Observable` macro for fine-grained updates
5. **Protocol-Oriented**: Extensive protocol usage for testability and flexibility

### Key Components
- **Data Layer**: Reads from `~/.claude/projects/` JSON files
- **ClaudeUsageClient**: Main API interface with multiple data source support (local, mock, API)
- **Analytics Services**: Cost calculation, deduplication, statistics aggregation
- **ClaudeLiveMonitor**: Real-time session tracking (local package dependency)
- **MenuBarContentView**: Main SwiftUI interface for macOS menu bar

### Testing Strategy
- Unit tests with mock data providers and dependency injection
- Test container (`TestDependencyContainer`) for isolated testing
- Mock implementations for all major services
- Real data testing capabilities with actual Claude usage files

## Development Notes

### Data Flow
1. Usage data is read from `~/.claude/projects/*.json` files
2. Data is parsed into strongly-typed Swift models matching Claude's backend
3. Repository layer provides filtered access to usage records
4. Services calculate analytics, costs, and statistics
5. ViewModels expose data to SwiftUI views with published properties

### Adding New Features
- Follow existing SOLID principles and clean architecture patterns
- Use dependency injection for new services
- Add protocol definitions before implementations
- Include comprehensive unit tests with mock data
- Update both SDK and UI layers as needed

### Menu Bar App Specifics
- Uses `MenuBarExtra` for macOS menu bar integration
- Real-time cost tracking with automatic updates
- Background refresh via `ClaudeLiveMonitor` package
- Cost calculations use model-specific pricing from `ClaudeModelConfiguration`