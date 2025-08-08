# ClaudeCodeUsage

A Swift SDK for accessing and analyzing Claude Code usage data from the Claudia desktop application.

## Features

- 📊 **Comprehensive Usage Statistics** - Access detailed usage data including costs, tokens, and session information
- 🔍 **Flexible Data Sources** - Support for Tauri API, local file parsing, or mock data
- 📈 **Advanced Analytics** - Built-in analytics for trends, predictions, and cost breakdowns  
- 🎯 **Type-Safe Models** - Strongly typed Swift models matching the Claudia backend
- 📱 **Multi-Platform** - Works on iOS, macOS, tvOS, and watchOS
- 🚀 **High Performance** - Efficient parsing and caching for large datasets

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "path/to/ClaudiaUsageSDK", from: "1.0.0")
]
```

Or in Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select version and add to your target

## Quick Start

```swift
import ClaudiaUsageSDK

// Initialize the client
let client = ClaudiaUsageClient()

// Fetch overall usage stats
Task {
    do {
        let stats = try await client.getUsageStats()
        print("Total cost: \(stats.totalCost.asCurrency)")
        print("Total sessions: \(stats.totalSessions)")
        print("Average cost per session: \(stats.averageCostPerSession.asCurrency)")
    } catch {
        print("Error fetching stats: \(error)")
    }
}
```

## Usage Examples

### Fetching Usage by Date Range

```swift
let client = ClaudiaUsageClient()

// Get last 7 days of usage
let endDate = Date()
let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!

Task {
    let stats = try await client.getUsageByDateRange(
        startDate: startDate,
        endDate: endDate
    )
    
    // Display daily breakdown
    for daily in stats.byDate {
        print("\(daily.date): \(daily.totalCost.asCurrency)")
    }
}
```

### Using Predefined Time Ranges

```swift
// Using the TimeRange enum for common periods
let timeRange = TimeRange.last30Days
let dateStrings = timeRange.apiDateStrings

Task {
    let stats = try await client.getUsageByDateRange(
        startDate: ISO8601DateFormatter().date(from: dateStrings.start)!,
        endDate: ISO8601DateFormatter().date(from: dateStrings.end)!
    )
}
```

### Analyzing Usage Patterns

```swift
let client = ClaudiaUsageClient()

Task {
    let stats = try await client.getUsageStats()
    
    // Cost breakdown by model
    let breakdown = UsageAnalytics.costBreakdown(from: stats)
    for item in breakdown {
        print("\(item.model): \(item.percentage.asPercentage) (\(item.cost.asCurrency))")
    }
    
    // Token usage breakdown
    let tokenBreakdown = UsageAnalytics.tokenBreakdown(from: stats)
    print(tokenBreakdown.description)
    
    // Weekly trends
    let trends = UsageAnalytics.weeklyTrends(from: stats.byDate)
    print("Weekly trend: \(trends.description)")
    
    // Predict monthly cost
    let predictedCost = UsageAnalytics.predictMonthlyCost(from: stats, daysElapsed: 7)
    print("Predicted monthly cost: \(predictedCost.asCurrency)")
}
```

### Working with Session Data

```swift
let client = ClaudiaUsageClient()

Task {
    // Get top expensive sessions
    let projects = try await client.getSessionStats(order: .descending)
    
    let topExpensive = UsageAnalytics.topExpensiveSessions(from: projects, limit: 5)
    for project in topExpensive {
        print("\(project.projectName): \(project.totalCost.asCurrency)")
    }
    
    // Filter and sort projects
    let sortedProjects = projects
        .sorted(by: .tokens, ascending: false)
        .prefix(10)
    
    for project in sortedProjects {
        print("\(project.projectName): \(project.totalTokens.abbreviated) tokens")
    }
}
```

### Cache Savings Analysis

```swift
Task {
    let stats = try await client.getUsageStats()
    
    let savings = UsageAnalytics.cacheSavings(from: stats)
    print("Cache savings: \(savings.description)")
}
```

### Using Different Data Sources

```swift
// Connect to Tauri API
let apiClient = ClaudiaUsageClient(
    dataSource: .tauriAPI(baseURL: URL(string: "http://localhost:1420")!)
)

// Parse local files
let localClient = ClaudiaUsageClient(
    dataSource: .localFiles(basePath: NSHomeDirectory() + "/.claude")
)

// Use mock data for testing
let mockClient = ClaudiaUsageClient(dataSource: .mock)
```

## Data Models

### Core Models

- `UsageStats` - Overall usage statistics with breakdowns
- `UsageEntry` - Individual usage record
- `ModelUsage` - Usage aggregated by model
- `DailyUsage` - Daily usage summary
- `ProjectUsage` - Project-level usage data

### Analytics Types

- `TokenBreakdown` - Token usage percentages by type
- `WeeklyTrend` - Week-over-week trend analysis
- `CacheSavings` - Cache effectiveness metrics
- `ChartDataPoint` - Ready-to-use chart data

## Analytics Features

The SDK includes powerful analytics capabilities:

- **Cost Analysis**: Breakdown by model, project, and time period
- **Trend Detection**: Weekly and monthly trends
- **Predictions**: Monthly cost predictions based on current usage
- **Peak Hours**: Identify when usage is highest
- **Cache Efficiency**: Calculate savings from cache usage
- **Filtering**: Filter data by date, model, project, or cost

## SwiftUI Integration

The SDK is designed to work seamlessly with SwiftUI:

```swift
import SwiftUI
import ClaudiaUsageSDK

struct UsageDashboard: View {
    @State private var stats: UsageStats?
    @State private var isLoading = true
    
    private let client = ClaudiaUsageClient()
    
    var body: some View {
        NavigationView {
            if isLoading {
                ProgressView()
            } else if let stats = stats {
                List {
                    Section("Overview") {
                        LabeledContent("Total Cost", value: stats.totalCost.asCurrency)
                        LabeledContent("Total Sessions", value: "\(stats.totalSessions)")
                        LabeledContent("Avg Cost/Session", value: stats.averageCostPerSession.asCurrency)
                    }
                    
                    Section("By Model") {
                        ForEach(stats.byModel) { model in
                            HStack {
                                Text(model.model)
                                Spacer()
                                Text(model.totalCost.asCurrency)
                            }
                        }
                    }
                }
                .navigationTitle("Usage Dashboard")
            }
        }
        .task {
            do {
                stats = try await client.getUsageStats()
                isLoading = false
            } catch {
                print("Error: \(error)")
            }
        }
    }
}
```

## Error Handling

The SDK provides detailed error types:

```swift
do {
    let stats = try await client.getUsageStats()
} catch UsageClientError.httpError(let code) {
    print("HTTP error with code: \(code)")
} catch UsageClientError.decodingError(let error) {
    print("Failed to decode: \(error)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Performance Considerations

- **Caching**: Consider caching results for frequently accessed data
- **Pagination**: Use `limit` parameter for large datasets
- **Background Processing**: Perform heavy analytics on background queues
- **Incremental Updates**: Fetch only new data when possible

## Requirements

- iOS 15.0+ / macOS 12.0+ / tvOS 15.0+ / watchOS 8.0+
- Swift 5.9+
- Xcode 15.0+

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

For issues, questions, or suggestions, please open an issue on GitHub.