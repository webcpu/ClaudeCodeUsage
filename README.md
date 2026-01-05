# ClaudeCodeUsage

A macOS menu bar app for tracking Claude Code usage and costs in real-time.

## Features

- **Menu Bar Cost Display** - Today's cost always visible in menu bar
- **Live Session Monitoring** - Active session indicator with real-time updates
- **Usage Analytics** - Daily, weekly, and monthly breakdowns
- **Yearly Heatmap** - GitHub-style contribution heatmap for cost visualization
- **Cost Alerts** - Visual warnings when daily spending exceeds threshold
- **Open at Login** - Optional automatic launch on system startup

## Data Source

Reads usage data from `~/.claude/projects/` (Claude Code's local storage).

## Build & Run

```bash
cd Packages/ClaudeUsage
swift build        # Build all targets
swift test         # Run all tests
```

## Architecture

### High-Level Overview

The application consists of two main features built on a shared foundation:

- **Glance** - Menu bar app for real-time monitoring (today's cost, active session, burn rate)
- **Insights** - Main window for analytics and history (model breakdown, daily trends, yearly heatmap)
- **App** - Shared foundation layer (data access, parsing, file system monitoring)

### Package Structure

```
Packages/ClaudeUsage/Sources/
├── App/                          # Shared foundation layer
│   ├── Domain/                   # Core types (UsageEntry, TokenCounts)
│   ├── Data/                     # Data access (UsageProvider, JSONLParser)
│   ├── Infrastructure/           # System services (DirectoryMonitor)
│   └── Shared/                   # Utilities (Composition, AppEnvironment)
│
├── Glance/                       # Menu bar feature
│   ├── Domain/                   # TodayCost, UsageSession, SessionFinder
│   ├── Data/                     # GlanceService, TodayCostProvider, SessionProvider
│   ├── Stores/                   # GlanceStore (@Observable)
│   ├── Infrastructure/           # RefreshCoordinator, Clock, Monitors
│   └── Views/                    # GlanceView, GlanceLabel, components
│
└── Insights/                     # Main window feature
    ├── Domain/                   # UsageStats, UsageAggregator, PricingCalculator
    ├── Data/                     # InsightsService
    ├── Stores/                   # InsightsStore (@Observable)
    └── Views/                    # InsightsView, AnalyticsView, Heatmap
```

### Clean Architecture Layers

Each feature follows this consistent layered architecture:

| Layer | Responsibility | Examples |
|-------|----------------|----------|
| **Views** | SwiftUI rendering, @Environment injection | `GlanceView`, `InsightsView` |
| **Stores** | @Observable state containers | `GlanceStore`, `InsightsStore` |
| **Data** | Actor-based orchestration, caching | `GlanceService`, `InsightsService` |
| **Domain** | Pure business logic, no I/O | `SessionFinder`, `UsageAggregator` |

### Data Flow

![Data Flow](docs/diagrams/data-flow.svg)

Data flows from the filesystem through parsing and caching layers to the UI:

1. **FileDiscovery** scans `~/.claude/projects/` for `.jsonl` files
2. **JSONLParser** parses entries with deduplication
3. **UsageProvider** (actor) caches parsed entries by file modification date
4. **Feature Services** transform raw entries into domain objects
5. **Stores** hold observable state for SwiftUI views

### Refresh Coordination (Glance)

![Refresh Coordination](docs/diagrams/refresh-coordination.svg)

The Glance feature stays up-to-date through multiple event monitors:

| Monitor | Trigger | Cache |
|---------|---------|-------|
| FileChangeMonitor | `.jsonl` file changes | Invalidate |
| DayChangeMonitor | Midnight transition | Invalidate |
| FallbackTimer | Periodic (5-10 min) | Preserve |
| WakeMonitor | System wake | Invalidate |

### Key Design Patterns

| Pattern | Implementation |
|---------|----------------|
| **Actor Isolation** | `UsageProvider`, `GlanceService`, `InsightsService` |
| **@Observable** | `GlanceStore`, `InsightsStore` for SwiftUI |
| **Protocol-Oriented** | `UsageProviding`, `SessionProviding`, `RefreshMonitor` |
| **Strategy Pattern** | `AggregationStrategy<T>` with functional composition |
| **Factory Pattern** | `RefreshCoordinatorFactory` for OCP-compliant assembly |

## Requirements

- macOS 15.0+
- Swift 6.0+

## License

MIT
