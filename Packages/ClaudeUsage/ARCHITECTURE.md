# Software Architecture

## Vertical Slice Architecture

The codebase uses **vertical slices** where MainWindow is a pure presentation layer and MenuBar owns the data pipeline.

```
┌─────────────────────────────────────────────────────────────────┐
│                            App                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  AppEnvironment (DI)                                      │  │
│  │  Screenshots                                              │  │
│  └───────────────────────────────────────────────────────────┘  │
└──────────────────────────────┬──────────────────────────────────┘
                               │
              ┌────────────────┴────────────────┐
              │                                 │
              ▼                                 ▼
┌─────────────────────────────┐   ┌─────────────────────────────┐
│        MainWindow           │   │          MenuBar            │
│    (Analytics Dashboard)    │   │    (Live Session Monitor)   │
├─────────────────────────────┤   ├─────────────────────────────┤
│ Views only                  │   │ Stores (shared via Env)     │
│  MainView                   │   │  UsageStore                 │
│  Overview/                  │   │  Loading/                   │
│  Models/                    │   ├─────────────────────────────┤
│  Daily/                     │   │ Infrastructure              │
│  Heatmap/                   │   │  Clock/, Settings/          │
│  Cards/                     │   │  AppConfiguration           │
│  Components/                │   ├─────────────────────────────┤
│                             │   │ Domain                      │
│                             │   │  UsageEntry, TokenCounts    │
│                             │   │  SessionBlock, BurnRate     │
│                             │   │  UsageAggregator, etc.      │
│                             │   ├─────────────────────────────┤
│                             │   │ Data                        │
│                             │   │  UsageRepository            │
│                             │   │  FileDiscovery, JSONLParser │
│                             │   │  SessionMonitor             │
│                             │   │  DirectoryMonitor           │
│                             │   │  Refresh/*                  │
│                             │   ├─────────────────────────────┤
│                             │   │ Views                       │
│                             │   │  MenuBarScene               │
│                             │   │  MenuBarContentView         │
│                             │   │  Sections/, Components/     │
└─────────────────────────────┘   └─────────────────────────────┘
```

## Package Structure

```
Packages/ClaudeUsage/Sources/
├── App/                          # Minimal composition root
│   ├── AppEnvironment.swift      # DI container
│   ├── AppEnvironment+Preview.swift
│   ├── Screenshots.swift         # Screenshot capture support
│   ├── Previews.swift
│   └── AppLifecycleManager.swift
│
├── MainWindow/                   # Pure presentation layer
│   └── Views/
│       ├── MainView.swift
│       ├── AnalyticsView.swift
│       ├── ContentStateRouter.swift
│       ├── EmptyStateView.swift
│       ├── Components/           # CaptureCompatibleScrollView
│       ├── Overview/             # OverviewView, MetricCard
│       ├── Models/               # ModelsView
│       ├── Daily/                # DailyUsageView, Charts/
│       ├── Cards/                # Analytics cards
│       └── Heatmap/              # YearlyCostHeatmap + subfolders
│
└── MenuBar/                      # Full vertical slice (owns data pipeline)
    ├── Infrastructure/           # Cross-cutting concerns
    │   ├── Clock/                # ClockProtocol, SystemClock
    │   ├── Settings/             # AppSettingsService, OpenAtLoginToggle
    │   └── AppConfiguration.swift
    ├── Stores/                   # Central state (shared via Environment)
    │   ├── UsageStore.swift
    │   └── Loading/              # UsageDataLoader, LoadTrace, TestClock
    ├── Domain/                   # All domain models
    │   ├── UsageEntry.swift
    │   ├── TokenCounts.swift
    │   ├── Composition.swift
    │   ├── SessionBlock.swift
    │   ├── BurnRate.swift
    │   ├── UsageStats.swift
    │   ├── UsageAggregator.swift
    │   ├── UsageAnalytics.swift
    │   ├── PricingCalculator.swift
    │   ├── RefreshMonitor.swift
    │   ├── RefreshReason.swift
    │   └── UsageDataSource.swift
    ├── Data/                     # All data access
    │   ├── UsageRepository.swift
    │   ├── FileDiscovery.swift
    │   ├── JSONLParser.swift
    │   ├── SessionMonitor.swift
    │   ├── DirectoryMonitor.swift
    │   └── Refresh/
    │       ├── RefreshCoordinator.swift
    │       ├── RefreshCoordinatorFactory.swift
    │       ├── RefreshConfig.swift
    │       └── Monitors/
    └── Views/
        ├── MenuBarScene.swift
        ├── MenuBarContentView.swift
        ├── Sections/
        ├── Components/
        ├── SessionMetrics/
        ├── Helpers/
        └── Theme/
```

## Data Flow

```
~/.claude/projects/*.jsonl
         │
         ▼
┌─────────────────────────────┐
│  DirectoryMonitor           │  FSEvents (MenuBar/Data)
└─────────────┬───────────────┘
              │
┌─────────────▼───────────────┐
│ RefreshCoordinator          │  Coordinates refresh triggers
│  ├─ FileChangeMonitor       │  (MenuBar/Data/Refresh)
│  ├─ DayChangeMonitor        │
│  ├─ WakeMonitor             │
│  └─ FallbackTimer           │
└─────────────┬───────────────┘
              │ closure callback
┌─────────────▼───────────────┐
│    UsageStore               │  @Observable (MenuBar/Stores)
└─────────────┬───────────────┘
              │
┌─────────────▼───────────────┐
│  UsageDataLoader            │  Orchestrates loading
└─────────────┬───────────────┘
              │
    ┌─────────┴─────────┐
    │                   │
    ▼                   ▼
┌────────────────┐  ┌────────────────┐
│UsageRepository │  │ SessionMonitor │
│(MenuBar/Data)  │  │(MenuBar/Data)  │
└────────────────┘  └────────────────┘
              │
              ▼
┌─────────────────────────────┐
│   MenuBar/Domain Models     │
│   UsageEntry, TokenCounts   │
└─────────────────────────────┘
              │
       ┌──────┴──────┐
       ▼             ▼
  MainWindow      MenuBar
    Views          Views
```

## Design Principles

### MainWindow = Pure Presentation

MainWindow contains only Views - no Domain or Data layers:
- Reads from UsageStore (injected via Environment)
- Contains view-specific logic in Heatmap/Stores (HeatmapStore)
- No direct data access - all data comes through UsageStore

### MenuBar = Full Vertical Slice

MenuBar owns the complete data pipeline:
- **Infrastructure**: Clock, Settings, AppConfiguration
- **Stores**: UsageStore (shared via Environment)
- **Domain**: All domain models (UsageEntry, TokenCounts, etc.)
- **Data**: Repository, parsers, monitors, refresh coordination
- **Views**: Menu bar UI

### App/ = Minimal Composition Root

App/ contains only what's truly shared:
- **AppEnvironment**: DI container that wires dependencies
- **Screenshots**: Bridges both slices for screenshot capture
- **Previews**: SwiftUI preview support

### Clear Dependency Direction

```
MainWindow ──► Environment ◄── MenuBar
                   │
                   ▼
              UsageStore
           (owned by MenuBar)
```

MainWindow and MenuBar never depend on each other directly.
They share state through SwiftUI Environment.

## Key Design Patterns

- **Repository Pattern**: UsageRepository, SessionMonitor abstract data access
- **Actor Concurrency**: Thread-safe state with actors
- **@Observable**: Modern SwiftUI state management in UsageStore
- **Factory Pattern**: RefreshCoordinatorFactory assembles monitors
- **Descriptor Pattern (OCP)**: RefreshReason, MenuButtonStyle for extensibility
- **Environment Injection**: UsageStore shared via SwiftUI @Environment
