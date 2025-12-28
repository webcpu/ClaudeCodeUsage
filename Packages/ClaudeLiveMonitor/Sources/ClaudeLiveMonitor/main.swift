import Foundation
import ClaudeLiveMonitorLib

// MARK: - Command Line Interface

struct CLI {
    static func printHelp() {
        print("""
        Claude Live Token Usage Monitor

        Usage: claude-monitor [options]

        Options:
          -t, --token-limit <number>  Set token limit for quota warnings
                                      Use 'max' or 'auto' to use maximum from previous sessions
                                      (default: auto)
          -r, --refresh <seconds>     Refresh interval (default: 1)
          -s, --session <hours>       Session window duration in hours (default: 5)
          -h, --help                  Show this help message

        Display Sections:
          SESSION     Time progress within the current session window
          USAGE       Tokens and cost accumulated in current session window
          PROJECTION  Estimated totals if current burn rate continues

        The session window (default 5h) aligns with Claude's rate limit reset period.
        Cost shown is API cost within this window, not calendar day.

        Examples:
          claude-monitor                      # Auto-detect limit from history
          claude-monitor --token-limit max    # Use max from previous sessions
          claude-monitor --token-limit 500000 # Set specific limit
          claude-monitor -t 1000000 -r 2 -s 5 # Multiple options

        Environment Variables:
          CLAUDE_CONFIG_DIR  Comma-separated paths to Claude data directories

        Press Ctrl+C to stop monitoring.
        """)
    }
    
    static func parseArguments() -> (tokenLimit: Int?, refreshInterval: TimeInterval, sessionDuration: Double, shouldExit: Bool) {
        let args = CommandLine.arguments
        var tokenLimit: Int?
        var refreshInterval: TimeInterval = 1.0
        var sessionDuration: Double = 5.0
        
        var i = 1
        while i < args.count {
            let arg = args[i]
            
            switch arg {
            case "-h", "--help":
                return (nil, 0, 0, true)
                
            case "-t", "--token-limit":
                i += 1
                if i < args.count {
                    let value = args[i]
                    if value == "max" || value == "auto" {
                        // Will be handled later
                        tokenLimit = nil
                    } else if let limit = Int(value) {
                        tokenLimit = limit
                    }
                }
                
            case "-r", "--refresh":
                i += 1
                if i < args.count, let interval = Double(args[i]) {
                    refreshInterval = interval
                }
                
            case "-s", "--session":
                i += 1
                if i < args.count, let hours = Double(args[i]) {
                    sessionDuration = hours
                }
                
            default:
                break
            }
            
            i += 1
        }
        
        return (tokenLimit, refreshInterval, sessionDuration, false)
    }
}

// MARK: - Main

func main() async {
    // Parse command line arguments
    let (tokenLimit, refreshInterval, sessionDuration, shouldExit) = CLI.parseArguments()
    
    if shouldExit {
        CLI.printHelp()
        exit(0)
    }
    
    // Determine Claude paths
    var claudePaths: [String] = []
    
    // Check environment variable first
    if let envPaths = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"] {
        claudePaths = envPaths.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
    } else {
        // Default paths
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        claudePaths = [
            "\(homeDir)/.config/claude",
            "\(homeDir)/.claude"
        ]
    }
    
    // Filter existing paths
    let existingPaths = claudePaths.filter { FileManager.default.fileExists(atPath: $0) }
    
    if existingPaths.isEmpty {
        print("Error: No Claude data directories found.")
        print("Searched paths:", claudePaths.joined(separator: ", "))
        exit(1)
    }
    
    print("Found Claude data directories:", existingPaths.joined(separator: ", "))
    
    // Create monitor configuration
    let config = LiveMonitorConfig(
        claudePaths: existingPaths,
        sessionDurationHours: sessionDuration,
        tokenLimit: tokenLimit,
        refreshInterval: refreshInterval,
        order: .descending
    )
    
    // Create monitor and renderer
    let monitor = LiveMonitor(config: config)
    
    // Determine effective token limit
    var effectiveLimit = tokenLimit
    if effectiveLimit == nil {
        effectiveLimit = await monitor.getAutoTokenLimit()
        if let limit = effectiveLimit {
            print("\u{001B}[33mUsing max tokens from previous sessions: \(limit)\u{001B}[0m")
        }
    }
    
    let renderer = LiveRenderer(monitor: monitor, tokenLimit: effectiveLimit)
    
    // Hide cursor
    print("\u{001B}[?25l", terminator: "")
    
    // Set up signal handler for graceful exit
    signal(SIGINT) { _ in
        // Show cursor
        print("\u{001B}[?25h")
        print("\nMonitoring stopped.")
        exit(0)
    }
    
    // Main loop
    while true {
        await renderer.render()
        try? await Task.sleep(nanoseconds: UInt64(refreshInterval * 1_000_000_000))
    }
}

// Run the async main function
Task {
    await main()
}
RunLoop.main.run()