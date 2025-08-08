# Claude Live Monitor

A Swift implementation of a live token usage monitor for Claude Code, providing real-time tracking of API usage, costs, and burn rates.

## Features

- 📊 **Real-time Monitoring**: Live updates of token usage and costs
- 🔥 **Burn Rate Analysis**: Track token consumption rate per minute
- 📈 **Usage Projections**: Predict total usage for the current session
- 💰 **Cost Tracking**: Calculate costs based on model-specific pricing
- 🎯 **Token Limit Warnings**: Visual alerts when approaching or exceeding limits
- 🔄 **Auto-refresh**: Updates every second (configurable)
- 📦 **Session Blocks**: Groups usage into 5-hour billing periods

## Installation

### Using Swift Package Manager

```bash
git clone https://github.com/yourusername/ClaudeLiveMonitor.git
cd ClaudeLiveMonitor
swift build -c release
```

The executable will be at `.build/release/claude-monitor`

### System-wide Installation

```bash
swift build -c release
sudo cp .build/release/claude-monitor /usr/local/bin/
```

## Usage

### Basic Usage

```bash
# Auto-detect token limit from previous sessions
claude-monitor

# Set a specific token limit
claude-monitor --token-limit 500000

# Use maximum from previous sessions
claude-monitor --token-limit max
```

### Command Line Options

- `-t, --token-limit <number>`: Set token limit for quota warnings (or 'max'/'auto')
- `-r, --refresh <seconds>`: Refresh interval (default: 1)
- `-s, --session <hours>`: Session duration in hours (default: 5)
- `-h, --help`: Show help message

### Environment Variables

- `CLAUDE_CONFIG_DIR`: Comma-separated paths to Claude data directories

## Library Usage

You can also use ClaudeLiveMonitor as a library in your Swift projects:

```swift
import ClaudeLiveMonitorLib

let config = LiveMonitorConfig(
    claudePaths: ["/path/to/.claude"],
    sessionDurationHours: 5,
    tokenLimit: 500000
)

let monitor = LiveMonitor(config: config)

if let activeBlock = monitor.getActiveBlock() {
    print("Current tokens: \(activeBlock.tokenCounts.total)")
    print("Burn rate: \(activeBlock.burnRate.tokensPerMinute) tokens/min")
    print("Cost: $\(activeBlock.costUSD)")
}
```

## Architecture

The package is organized into several modules:

- **Models**: Data structures for tokens, usage entries, and session blocks
- **JSONLParser**: Parses Claude's JSONL usage files
- **LiveMonitor**: Core monitoring logic and session block identification
- **LiveRenderer**: Terminal UI rendering with ANSI escape codes

## Requirements

- Swift 5.9 or later
- macOS 13.0 or later
- Claude Code usage data in `~/.claude/projects/` or `~/.config/claude/projects/`

## License

MIT