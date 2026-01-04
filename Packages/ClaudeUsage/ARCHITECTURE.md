# Software Architecture

## Vertical Slice Architecture

The codebase uses **vertical slices** where each UI container owns its complete stack (Domain → Data → Views).

```
┌─────────────────────────────────────────────────────────────────┐
│                            App                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Domain: UsageEntry, TokenCounts, Composition             │  │
│  │  Charts                                                   │  │
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
│ Domain                      │   │ Domain                      │
│  UsageStats                 │   │  SessionBlock               │
│  UsageAggregator            │   │  BurnRate                   │
│  UsageAnalytics             │   │  RefreshMonitor             │
├─────────────────────────────┤   ├─────────────────────────────┤
│ Data                        │   │ Data                        │
│  UsageRepository            │   │  SessionMonitor             │
│  FileDiscovery              │   │  DirectoryMonitor           │
│  JSONLParser                │   │  Refresh/*                  │
├─────────────────────────────┤   ├─────────────────────────────┤
│ Views                       │   │ Views                       │
│  MainView                   │   │  MenuBarScene               │
│  Overview/                  │   │  MenuBarContentView         │
│  Models/                    │   │  Sections/                  │
│  Daily/                     │   │  Components/                │
│  Heatmap/                   │   │  SessionMetrics/            │
│  Cards/                     │   │  Theme/                     │
└─────────────────────────────┘   └─────────────────────────────┘
```

## Package Structure

```
Packages/ClaudeUsage/Sources/
├── App/                          # Composition root + shared types
│   ├── AppEnvironment.swift      # DI container
│   ├── Screenshots.swift         # Screenshot capture support
│   ├── Domain/                   # Shared domain types
│   │   ├── UsageEntry.swift
│   │   ├── TokenCounts.swift
│   │   └── Composition.swift
│   └── Charts/                   # Shared chart components
│
├── MainWindow/                   # MainWindow vertical slice
│   ├── Previews.swift            # Preview support
│   ├── Domain/
│   │   ├── PricingCalculator.swift
│   │   ├── UsageStats.swift
│   │   ├── UsageAggregator.swift
│   │   └── UsageAnalytics.swift
│   ├── Data/
│   │   ├── UsageRepository.swift
│   │   ├── FileDiscovery.swift
│   │   └── JSONLParser.swift
│   └── Views/
│       ├── MainView.swift
│       ├── AnalyticsView.swift
│       ├── Components/           # MainWindow-specific components
│       ├── Overview/
│       ├── Models/
│       ├── Daily/
│       ├── Heatmap/
│       └── Cards/
│
└── MenuBar/                      # MenuBar vertical slice
    ├── AppLifecycleManager.swift # App lifecycle management
    ├── Infrastructure/           # MenuBar-owned infrastructure
    │   ├── Clock/                # Time abstraction
    │   ├── Settings/             # App settings
    │   └── AppConfiguration.swift
    ├── Stores/                   # Central state (shared via Environment)
    │   ├── UsageStore.swift
    │   └── Loading/
    ├── Domain/
    │   ├── SessionBlock.swift
    │   ├── BurnRate.swift
    │   ├── RefreshMonitor.swift
    │   ├── RefreshReason.swift
    │   └── UsageDataSource.swift
    ├── Data/
    │   ├── SessionMonitor.swift
    │   ├── DirectoryMonitor.swift
    │   └── Refresh/
    │       ├── RefreshCoordinator.swift
    │       └── Monitors/
    └── Views/
        ├── MenuBarScene.swift
        ├── MenuBarContentView.swift
        ├── Sections/
        ├── Components/
        ├── SessionMetrics/
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
│    UsageStore               │  @Observable (App/Stores)
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
│(MainWindow/Data)│ │(MenuBar/Data)  │
└────────────────┘  └────────────────┘
              │
              ▼
┌─────────────────────────────┐
│     App/Domain Models       │
│   UsageEntry, TokenCounts   │
└─────────────────────────────┘
              │
       ┌──────┴──────┐
       ▼             ▼
  MainWindow      MenuBar
    Views          Views
```

## Design Principles

### Vertical Slice Benefits

1. **Ownership**: MainWindow owns analytics, MenuBar owns monitoring
2. **Cohesion**: Domain + Data + Views live together
3. **Independence**: Change MainWindow without touching MenuBar
4. **Navigation**: Find everything about a feature in one place

### App/ as Composition Root

The `App/` folder serves as the **composition root** and shared foundation:
- **Composition Root**: AppEnvironment wires all dependencies
- **Shared Domain**: Types used by both slices (UsageEntry, TokenCounts)
- **Charts**: Shared chart components (HourlyCostChart)

### MenuBar/ Owns Infrastructure and State

MenuBar owns its infrastructure and the central state:
- **Stores**: UsageStore (shared via Environment, drives both slices)
- **Clock**: Time abstraction for refresh monitors
- **Settings**: App settings service and Open at Login toggle
- **AppConfiguration**: App-wide configuration and paths

### Clear Dependency Direction

```
MainWindow ──┐
             ├──► App (shared)
MenuBar ─────┘
```

Both vertical slices depend on App/, but never on each other.

## Key Design Patterns

- **Repository Pattern**: UsageRepository, SessionMonitor abstract data access
- **Actor Concurrency**: Thread-safe state with actors
- **@Observable**: Modern SwiftUI state management in UsageStore
- **Factory Pattern**: RefreshCoordinatorFactory assembles monitors
- **Descriptor Pattern (OCP)**: RefreshReason, MenuButtonStyle for extensibility
