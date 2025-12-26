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
swift build
swift run ClaudeCodeUsage
```

## Requirements

- macOS 14.0+
- Swift 5.9+

## License

MIT
