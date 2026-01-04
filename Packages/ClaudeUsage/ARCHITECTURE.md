# Software Architecture

## Two-Store Architecture

The codebase uses **two independent stores** for clean separation:
- **InsightsStore** (Insights) - Historical usage analytics
- **GlanceStore** (Glance) - Live session monitoring

```
┌─────────────────────────────────────────────────────────────────┐
│                            App                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  AppEnvironment (DI)                                      │  │
│  │  App/Domain (UsageEntry, TokenCounts, UsageProviding)     │  │
│  │  App/Loading (UsageProvider, Parser, Monitor)             │  │
│  └───────────────────────────────────────────────────────────┘  │
└──────────────────────────────┬──────────────────────────────────┘
                               │
              ┌────────────────┴────────────────┐
              │                                 │
              ▼                                 ▼
┌─────────────────────────────┐   ┌─────────────────────────────┐
│          Insights           │   │           Glance            │
│    (Deep Analysis Window)   │   │    (Quick Check Menu Bar)   │
├─────────────────────────────┤   ├─────────────────────────────┤
│ Stores/                     │   │ Stores/                     │
│  InsightsStore              │   │  GlanceStore, Loading/      │
├─────────────────────────────┤   ├─────────────────────────────┤
│ Domain/                     │   │ Domain/                     │
│  UsageStats                 │   │  UsageSession, BurnRate     │
│  UsageAggregator            │   │  SessionDetector            │
│  UsageAnalytics             │   │  SessionProviding           │
│  PricingCalculator          │   │  RefreshMonitor/Reason      │
├─────────────────────────────┤   ├─────────────────────────────┤
│ Views/                      │   │ Infrastructure/             │
│  InsightsView               │   │  Clock/, Settings/, Refresh/│
│  Overview/, Models/         │   ├─────────────────────────────┤
│  Daily/, Heatmap/           │   │ Data/                       │
│  Cards/                     │   │  SessionProvider            │
│                             │   ├─────────────────────────────┤
│                             │   │ Views/                      │
│                             │   │  GlanceScene, GlanceView    │
│                             │   │  Sections/, Components/     │
│                             │   │  Theme/, Helpers/           │
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
│   ├── Domain/                   # Shared data types & protocols
│   │   ├── UsageEntry.swift
│   │   ├── TokenCounts.swift
│   │   ├── Composition.swift
│   │   └── UsageProviding.swift  # Protocol for usage data access
│   └── Loading/                  # Shared data loading
│       ├── FileDiscovery.swift
│       ├── JSONLParser.swift
│       ├── UsageProvider.swift   # Implements UsageProviding
│       └── DirectoryMonitor.swift
│
├── Insights/                     # Deep analysis vertical slice
│   ├── Domain/                   # Analytics domain
│   │   ├── UsageStats.swift
│   │   ├── UsageAggregator.swift
│   │   ├── UsageAnalytics.swift
│   │   └── PricingCalculator.swift
│   ├── Stores/
│   │   └── InsightsStore.swift   # Owns historical stats
│   └── Views/
│       ├── InsightsView.swift    # Main navigation view
│       ├── AnalyticsView.swift
│       ├── ContentStateRouter.swift
│       ├── EmptyStateView.swift
│       ├── Overview/             # OverviewView, MetricCard
│       ├── Models/               # ModelsView
│       ├── Daily/                # DailyUsageView, Charts/
│       ├── Heatmap/              # YearlyCostHeatmap, Grid/, Legend/, etc.
│       ├── Cards/                # Analytics cards
│       └── Components/           # CaptureCompatibleScrollView
│
└── Glance/                       # Quick check vertical slice
    ├── AppLifecycleManager.swift # Lifecycle handling for GlanceStore
    ├── Domain/                   # Session domain (pure logic)
    │   ├── UsageSession.swift
    │   ├── SessionDetector.swift # Pure session detection logic
    │   ├── SessionProviding.swift # Protocol for session data access
    │   ├── BurnRate.swift
    │   ├── RefreshMonitor.swift
    │   └── RefreshReason.swift
    ├── Infrastructure/           # External system integrations
    │   ├── Clock/                # ClockProtocol, SystemClock, TestClock
    │   ├── Settings/             # AppSettingsService, OpenAtLoginToggle
    │   ├── Refresh/              # RefreshCoordinator, Monitors/
    │   └── AppConfiguration.swift
    ├── Stores/
    │   ├── GlanceStore.swift     # Owns live session
    │   └── Loading/              # UsageDataLoader, LoadTrace
    ├── Data/                     # Data access layer
    │   └── SessionProvider.swift # Implements SessionProviding
    └── Views/
        ├── GlanceScene.swift     # Menu bar scene entry point
        ├── GlanceView.swift      # Main menu bar content view
        ├── Sections/             # CostMetricsSection, UsageMetricsSection
        ├── SessionMetrics/       # SessionMetricsSection
        ├── Components/           # ActionButtons, GraphView, MetricRow, etc.
        ├── Helpers/              # ColorService, FormatterService
        └── Theme/                # GlanceTheme, GlanceStyles
```

## Data Flow

```
~/.claude/projects/*.jsonl
         │
         ├─────────────────────────────────┐
         │                                 │
         ▼                                 ▼
┌─────────────────────┐         ┌─────────────────────┐
│    InsightsStore    │         │     GlanceStore     │
│     (Insights)      │         │      (Glance)       │
├─────────────────────┤         ├─────────────────────┤
│ Subscribes to       │         │ Subscribes to       │
│ DirectoryMonitor    │         │ RefreshCoordinator  │
├─────────────────────┤         ├─────────────────────┤
│ Loads via           │         │ Loads via           │
│ UsageProvider       │         │ UsageProvider +     │
│                     │         │ SessionProvider     │
├─────────────────────┤         ├─────────────────────┤
│ Transforms to       │         │ Transforms to       │
│ UsageStats          │         │ UsageSession        │
│ (historical)        │         │ (live)              │
└─────────┬───────────┘         └─────────┬───────────┘
          │                               │
          ▼                               ▼
      Insights                         Glance
       Views                           Views
```

## Naming Philosophy

The module names reflect user intent:
- **Insights** = "I want to analyze my usage" (deep analysis, open the window)
- **Glance** = "I want to check my session" (quick look, menu bar)

All components are named consistently with their module:
- **InsightsStore** + **InsightsView** for deep analysis
- **GlanceStore** + **GlanceView** + **GlanceScene** + **GlanceTheme** for quick glances

## Clean Architecture Layers

Each vertical slice (Insights, Glance) follows Clean Architecture layering:

```
┌─────────────────────────────────────────────────────┐
│ Views/              Presentation Layer              │
├─────────────────────────────────────────────────────┤
│ Stores/             Application Layer (Use Cases)   │
├─────────────────────────────────────────────────────┤
│ Domain/             Domain Layer (Entities)         │
├─────────────────────────────────────────────────────┤
│ Data/               Data Access (Providers)         │
│ Infrastructure/     External Systems (OS, Timers)   │
└─────────────────────────────────────────────────────┘
```

**Layer responsibilities:**
- **Domain/** - Pure business types and protocols (no external dependencies)
- **Data/** - Data access implementations (file system reads)
- **Infrastructure/** - External system adapters (timers, OS notifications, settings)
- **Stores/** - Application state and use cases
- **Views/** - SwiftUI presentation

Dependencies point inward: Views → Stores → Domain ← Data/Infrastructure

## Design Principles

### Independent Stores

Each store is fully independent:
- **InsightsStore**: Loads historical stats, subscribed to DirectoryMonitor
- **GlanceStore**: Loads live session, subscribed to RefreshCoordinator

Neither store depends on the other. They share the data loading layer
(App/Loading) but load and transform data independently.

### Domain Ownership

Each vertical slice owns its domain:
- **Insights/Domain**: Analytics types (UsageStats, UsageAggregator)
- **Glance/Domain**: Session types (UsageSession, SessionDetector, BurnRate)
- **App/Domain**: Shared types (UsageEntry, TokenCounts, UsageProviding)

Reading a Domain folder tells you what that slice does.
Domain contains pure business logic with no I/O dependencies.

### Clear Dependency Direction

```
Insights ──┐
           ├──► App (shared domain + loading)
Glance ────┘
```

Both vertical slices depend on App/, but never on each other.

## Key Design Patterns

- **Provider Pattern**: UsageProvider/SessionProvider abstract read-only data access
- **Pure Domain Logic**: SessionDetector contains pure detection algorithms (no I/O)
- **Actor Concurrency**: Thread-safe state with actors
- **@Observable**: Modern SwiftUI state management
- **Factory Pattern**: RefreshCoordinatorFactory assembles monitors
- **Environment Injection**: Both stores shared via SwiftUI @Environment
