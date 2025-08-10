# Type Namespacing Guide

## Overview
This project has two different `UsageEntry` types that serve different purposes:

### 1. ClaudeCodeUsage.UsageEntry
- **Location**: `Sources/ClaudeCodeUsage/Models/UsageModels.swift`
- **Purpose**: Historical usage data from Claude's JSONL files
- **Fields**: project, timestamp (String), model, tokens, cost, sessionId
- **Usage**: Reading and analyzing past usage data

### 2. ClaudeLiveMonitorLib.UsageEntry  
- **Location**: `Packages/ClaudeLiveMonitor/Sources/ClaudeLiveMonitorLib/Models.swift`
- **Purpose**: Real-time session monitoring
- **Fields**: timestamp (Date), usage (TokenCounts), costUSD, model, sourceFile
- **Usage**: Live tracking of current session

## Avoiding Conflicts

### Option 1: Selective Imports (Currently Used)
```swift
import ClaudeCodeUsage
// Import only specific types from ClaudeLiveMonitorLib
import struct ClaudeLiveMonitorLib.SessionBlock
import struct ClaudeLiveMonitorLib.BurnRate
```

### Option 2: Type Aliases (Recommended)
```swift
import ClaudeCodeUsage
import ClaudeLiveMonitorLib

// Use the provided type aliases
let historicalEntry: ClaudeUsageEntry = ...  // From ClaudeCodeUsage
let liveEntry: LiveUsageEntry = ...          // From ClaudeLiveMonitorLib
```

### Option 3: Fully Qualified Names
```swift
import ClaudeCodeUsage
import ClaudeLiveMonitorLib

let historicalEntry: ClaudeCodeUsage.UsageEntry = ...
let liveEntry: ClaudeLiveMonitorLib.UsageEntry = ...
```

## Convention
- When a file only uses types from one module, import that module normally
- When a file uses types from both modules, use Option 1 or 2 to avoid ambiguity
- The historical `UsageEntry` from ClaudeCodeUsage is the default in most contexts
- Use explicit qualification only when both types are needed in the same file

## Type Aliases Available

### ClaudeCodeUsage Module
- `ClaudeUsageEntry` → `UsageEntry`
- `ClaudeUsageStats` → `UsageStats`
- `ClaudeModelUsage` → `ModelUsage`
- `ClaudeDailyUsage` → `DailyUsage`
- `ClaudeProjectUsage` → `ProjectUsage`

### ClaudeLiveMonitorLib Module
- `LiveUsageEntry` → `UsageEntry`
- `LiveSessionBlock` → `SessionBlock`
- `LiveTokenCounts` → `TokenCounts`