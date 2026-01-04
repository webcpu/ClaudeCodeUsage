# Software Architecture

## Two-Store Architecture

The codebase uses **two independent stores** for clean separation:
- **AnalyticsStore** (MainWindow) - Historical usage analytics
- **SessionStore** (MenuBar) - Live session monitoring

```
┌─────────────────────────────────────────────────────────────────┐
│                            App                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  AppEnvironment (DI)                                      │  │
│  │  App/Domain (UsageEntry, TokenCounts)                     │  │
│  │  App/Loading (Repository, Parser, Monitor)                │  │
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
│ Stores/                     │   │ Stores/                     │
│  AnalyticsStore             │   │  SessionStore               │
├─────────────────────────────┤   ├─────────────────────────────┤
│ Domain/                     │   │ Domain/                     │
│  UsageStats                 │   │  SessionBlock               │
│  UsageAggregator            │   │  BurnRate                   │
│  UsageAnalytics             │   │  RefreshMonitor             │
│  PricingCalculator          │   │  RefreshReason              │
├─────────────────────────────┤   ├─────────────────────────────┤
│ Views/                      │   │ Infrastructure/             │
│  Overview/                  │   │  Clock/, Settings/          │
│  Models/                    │   ├─────────────────────────────┤
│  Daily/                     │   │ Data/                       │
│  Heatmap/                   │   │  SessionMonitor             │
│  Cards/                     │   │  Refresh/                   │
│                             │   ├─────────────────────────────┤
│                             │   │ Views/                      │
│                             │   │  Sections/                  │
│                             │   │  Components/                │
└─────────────────────────────┘   └─────────────────────────────┘
```

## Package Structure

```
Packages/ClaudeUsage/Sources/
├── App/                          # Shared composition root
│   ├── AppEnvironment.swift      # DI container (both stores)
│   ├── AppEnvironment+Preview.swift
│   ├── Screenshots.swift
│   ├── Previews.swift
│   ├── Domain/                   # Shared data types
│   │   ├── UsageEntry.swift
│   │   ├── TokenCounts.swift
│   │   └── Composition.swift
│   └── Loading/                  # Shared data loading
│       ├── FileDiscovery.swift
│       ├── JSONLParser.swift
│       ├── UsageRepository.swift
│       └── DirectoryMonitor.swift
│
├── MainWindow/                   # Analytics vertical slice
│   ├── Domain/                   # Analytics domain
│   │   ├── UsageStats.swift
│   │   ├── UsageAggregator.swift
│   │   ├── UsageAnalytics.swift
│   │   └── PricingCalculator.swift
│   ├── Stores/
│   │   └── AnalyticsStore.swift  # Owns historical stats
│   └── Views/
│       ├── MainView.swift
│       ├── AnalyticsView.swift
│       ├── Overview/
│       ├── Models/
│       ├── Daily/
│       ├── Heatmap/
│       └── Cards/
│
└── MenuBar/                      # Monitoring vertical slice
    ├── AppLifecycleManager.swift # Lifecycle handling for SessionStore
    ├── Domain/                   # Session domain
    │   ├── SessionBlock.swift
    │   ├── BurnRate.swift
    │   ├── RefreshMonitor.swift
    │   ├── RefreshReason.swift
    │   └── UsageDataSource.swift
    ├── Infrastructure/
    │   ├── Clock/
    │   ├── Settings/
    │   └── AppConfiguration.swift
    ├── Stores/
    │   ├── SessionStore.swift    # Owns live session
    │   └── Loading/
    ├── Data/
    │   ├── SessionMonitor.swift
    │   └── Refresh/
    └── Views/
        ├── MenuBarScene.swift
        ├── MenuBarContentView.swift
        ├── Sections/
        ├── Components/
        └── Theme/
```

## Data Flow

```
~/.claude/projects/*.jsonl
         │
         ├─────────────────────────────────┐
         │                                 │
         ▼                                 ▼
┌─────────────────────┐         ┌─────────────────────┐
│   AnalyticsStore    │         │    SessionStore     │
│   (MainWindow)      │         │    (MenuBar)        │
├─────────────────────┤         ├─────────────────────┤
│ Subscribes to       │         │ Subscribes to       │
│ DirectoryMonitor    │         │ RefreshCoordinator  │
├─────────────────────┤         ├─────────────────────┤
│ Loads via           │         │ Loads via           │
│ UsageRepository     │         │ UsageRepository +   │
│                     │         │ SessionMonitor      │
├─────────────────────┤         ├─────────────────────┤
│ Transforms to       │         │ Transforms to       │
│ UsageStats          │         │ SessionBlock        │
│ (historical)        │         │ (live)              │
└─────────┬───────────┘         └─────────┬───────────┘
          │                               │
          ▼                               ▼
    MainWindow                        MenuBar
      Views                            Views
```

## Design Principles

### Independent Stores

Each store is fully independent:
- **AnalyticsStore**: Loads historical stats, subscribed to DirectoryMonitor
- **SessionStore**: Loads live session, subscribed to RefreshCoordinator

Neither store depends on the other. They share the data loading layer
(App/Loading) but load and transform data independently.

### Domain Ownership

Each vertical slice owns its domain:
- **MainWindow/Domain**: Analytics types (UsageStats, UsageAggregator)
- **MenuBar/Domain**: Session types (SessionBlock, BurnRate)
- **App/Domain**: Shared types (UsageEntry, TokenCounts)

Reading a Domain folder tells you what that slice does.

### Clear Dependency Direction

```
MainWindow ──┐
             ├──► App (shared domain + loading)
MenuBar ─────┘
```

Both vertical slices depend on App/, but never on each other.

## Key Design Patterns

- **Repository Pattern**: UsageRepository abstracts data access
- **Actor Concurrency**: Thread-safe state with actors
- **@Observable**: Modern SwiftUI state management
- **Factory Pattern**: RefreshCoordinatorFactory assembles monitors
- **Environment Injection**: Both stores shared via SwiftUI @Environment
