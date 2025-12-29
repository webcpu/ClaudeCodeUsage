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

### Terminal

```bash
swift build
swift run ClaudeCodeUsage
```

### Xcode

1. Open `Package.swift` in Xcode
2. Select **ClaudeCodeUsage** scheme (top toolbar)
3. Press **⌘R** to build and run

## Architecture

```
ClaudeUsageCore   → Pure types, protocols, analytics
ClaudeUsageData   → Repository, parsing, session monitoring
ClaudeCodeUsage   → SwiftUI menu bar app (executable)
```

## Requirements

- macOS 15.0+
- Swift 6.0+

## License

MIT
