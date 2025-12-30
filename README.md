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

1. Open `ClaudeCodeUsage.xcodeproj`
2. Press **⌘R** to build and run

## Testing

```bash
make test          # Run all tests
make test-core     # Run ClaudeUsageCore tests
make test-data     # Run ClaudeUsageData tests
make test-ui       # Run ClaudeUsageUI tests
```

## Architecture

```
Packages/
├── ClaudeUsageCore/   → Pure types, protocols, analytics
├── ClaudeUsageData/   → Repository, parsing, session monitoring
└── ClaudeUsageUI/     → SwiftUI views and ViewModels

ClaudeCodeUsage/       → Xcode project (app entry point)
```

## Requirements

- macOS 15.0+
- Swift 6.0+

## License

MIT
