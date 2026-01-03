# Software Architecture

## Layer Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         App Layer                           │
│            (ClaudeCodeUsageApp - Entry Point)               │
└────────────────────────────┬────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────┐
│                   Presentation Layer                        │
│                     (ClaudeUsageUI)                         │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐   │
│  │    Views     │  │    Stores    │  │    Services     │   │
│  │  MenuBar/    │  │  UsageStore  │  │  LoadTrace      │   │
│  │  MainWindow/ │  │  HeatmapStore│  │  UsageDataLoader│   │
│  │  Shared/     │  │              │  │  TestClock      │   │
│  └──────────────┘  └──────────────┘  └─────────────────┘   │
└────────────────────────────┬────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────┐
│                       Data Layer                            │
│                    (ClaudeUsageData)                        │
│  ┌─────────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │   Repository    │  │   Refresh    │  │  Monitoring   │  │
│  │ UsageRepository │  │ Coordinator  │  │ SessionMonitor│  │
│  │ FileDiscovery   │  │ Monitors/*   │  │ DirectoryMon  │  │
│  └─────────────────┘  └──────────────┘  └───────────────┘  │
└────────────────────────────┬────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────┐
│                      Domain Layer                           │
│                    (ClaudeUsageCore)                        │
│  ┌───────────┐ ┌─────────┐ ┌─────────┐ ┌───────────────┐   │
│  │  Models   │ │Analytics│ │ Clock   │ │Configuration  │   │
│  │UsageEntry │ │Pricing  │ │Protocol │ │AppConfiguration│  │
│  │TokenCounts│ │Aggregator││SystemClk│ │ConfigService  │   │
│  │SessionBlk │ │         │ │         │ │               │   │
│  └───────────┘ └─────────┘ └─────────┘ └───────────────┘   │
│  ┌───────────┐ ┌─────────┐ ┌─────────────────────────────┐ │
│  │ Protocols │ │ Refresh │ │         Tracing             │ │
│  │UsageData  │ │Monitor  │ │LoadTracing, LoadPhase       │ │
│  │SessionData│ │Reason   │ │                             │ │
│  └───────────┘ └─────────┘ └─────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Package Structure

```
Packages/
├── ClaudeUsageCore/           # Domain Layer (no dependencies)
│   └── Sources/
│       ├── Models/            # UsageEntry, TokenCounts, SessionBlock, BurnRate
│       ├── Analytics/         # PricingCalculator, UsageAggregator
│       ├── Protocols/         # UsageDataSource, SessionDataSource
│       ├── Clock/             # ClockProtocol, SystemClock
│       ├── Configuration/     # AppConfiguration, ConfigurationService
│       ├── Refresh/           # RefreshMonitor, RefreshReason
│       └── Tracing/           # LoadTracing, LoadPhase
│
├── ClaudeUsageData/           # Data Layer (depends: Core)
│   └── Sources/
│       ├── Repository/        # UsageRepository, FileDiscovery
│       ├── Parsing/           # JSONLParser
│       ├── Monitoring/        # SessionMonitor, DirectoryMonitor
│       └── Refresh/           # RefreshCoordinator, RefreshConfig
│           └── Monitors/      # FileChange, DayChange, Wake, Timer
│
├── ClaudeUsageUI/             # Presentation Layer (depends: Core, Data)
│   └── Sources/
│       ├── Stores/            # UsageStore
│       │   └── Services/
│       │       ├── Clock/     # TestClock (test support)
│       │       └── Loading/   # LoadTrace, UsageDataLoader
│       ├── MenuBar/           # Menu bar views
│       ├── MainWindow/        # Main window views
│       ├── Shared/            # Shared components
│       └── Settings/          # User preferences
│
└── ScreenshotKit/             # Utility (standalone)
```

## Data Flow

```
~/.claude/projects/*.jsonl
         │
         ▼
┌─────────────────────────────┐
│  DirectoryMonitor (Data)    │  FSEvents
└─────────────┬───────────────┘
              │
┌─────────────▼───────────────┐
│ RefreshCoordinator (Data)   │  Coordinates refresh triggers
│  ├─ FileChangeMonitor       │
│  ├─ DayChangeMonitor        │
│  ├─ WakeMonitor             │
│  └─ FallbackTimer           │
└─────────────┬───────────────┘
              │ closure callback
┌─────────────▼───────────────┐
│    UsageStore (UI)          │  @Observable, @MainActor
└─────────────┬───────────────┘
              │
┌─────────────▼───────────────┐
│  UsageDataLoader (UI)       │  Orchestrates loading
└─────────────┬───────────────┘
              │
┌─────────────▼───────────────┐
│ UsageRepository (Data)      │  File parsing
│ SessionMonitor (Data)       │  Session detection + caching
└─────────────┬───────────────┘
              │
┌─────────────▼───────────────┐
│   Domain Models (Core)      │
└─────────────────────────────┘
              │
              ▼
         SwiftUI Views
```

## Dependency Rules

| Layer | Can Depend On |
|-------|---------------|
| **Core** | Nothing (pure Swift) |
| **Data** | Core |
| **UI** | Core, Data |
| **App** | UI |

## Key Design Patterns

- **Repository Pattern**: `UsageRepository` abstracts file system access
- **Actor Concurrency**: Thread-safe state with `UsageRepository`, `UsageDataLoader`, `SessionMonitor`
- **@Observable**: Modern SwiftUI state management in `UsageStore`
- **Factory Pattern**: `RefreshCoordinatorFactory` assembles monitor configurations
- **Protocol-Oriented**: `UsageDataSource`, `SessionDataSource`, `RefreshMonitor`, `ClockProtocol`, `LoadTracing`
- **Descriptor Pattern (OCP)**: `RefreshReason`, `Destination`, `MenuButtonStyle` for extensibility
