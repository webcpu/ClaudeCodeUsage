import Foundation
import ClaudeLiveMonitorLib

// MARK: - Constants

private enum Defaults {
    static let refreshInterval: TimeInterval = 1.0
    static let sessionDurationHours: Double = 5.0
}

private enum EnvironmentKey {
    static let claudeConfigDir = "CLAUDE_CONFIG_DIR"
}

private enum ANSICode {
    static let yellow = "\u{001B}[33m"
    static let reset = "\u{001B}[0m"
    static let hideCursor = "\u{001B}[?25l"
    static let showCursor = "\u{001B}[?25h"
}

// MARK: - Parsed Arguments

struct ParsedArguments {
    let tokenLimit: Int?
    let refreshInterval: TimeInterval
    let sessionDuration: Double
    let shouldShowHelp: Bool

    static let `default` = ParsedArguments(
        tokenLimit: nil,
        refreshInterval: Defaults.refreshInterval,
        sessionDuration: Defaults.sessionDurationHours,
        shouldShowHelp: false
    )
}

// MARK: - Argument Parsing

private enum ArgumentParser {
    static func parse(_ args: [String]) -> ParsedArguments {
        if containsHelpFlag(args) {
            return ParsedArguments(tokenLimit: nil, refreshInterval: 0, sessionDuration: 0, shouldShowHelp: true)
        }

        var tokenLimit: Int?
        var refreshInterval = Defaults.refreshInterval
        var sessionDuration = Defaults.sessionDurationHours
        var index = 1

        while index < args.count {
            let consumed = parseArgument(
                args: args,
                at: index,
                tokenLimit: &tokenLimit,
                refreshInterval: &refreshInterval,
                sessionDuration: &sessionDuration
            )
            index += consumed
        }

        return ParsedArguments(
            tokenLimit: tokenLimit,
            refreshInterval: refreshInterval,
            sessionDuration: sessionDuration,
            shouldShowHelp: false
        )
    }

    private static func containsHelpFlag(_ args: [String]) -> Bool {
        args.contains { $0 == "-h" || $0 == "--help" }
    }

    private static func parseArgument(
        args: [String],
        at index: Int,
        tokenLimit: inout Int?,
        refreshInterval: inout TimeInterval,
        sessionDuration: inout Double
    ) -> Int {
        let arg = args[index]
        let nextValue = args.indices.contains(index + 1) ? args[index + 1] : nil

        switch arg {
        case "-t", "--token-limit":
            tokenLimit = parseTokenLimit(nextValue)
            return 2

        case "-r", "--refresh":
            refreshInterval = nextValue.flatMap { Double($0) } ?? refreshInterval
            return 2

        case "-s", "--session":
            sessionDuration = nextValue.flatMap { Double($0) } ?? sessionDuration
            return 2

        default:
            return 1
        }
    }

    private static func parseTokenLimit(_ value: String?) -> Int? {
        guard let value else { return nil }
        return (value == "max" || value == "auto") ? nil : Int(value)
    }
}

// MARK: - Path Discovery

private enum PathDiscovery {
    static func discoverClaudePaths() -> [String] {
        environmentPaths() ?? defaultPaths()
    }

    static func filterExisting(_ paths: [String]) -> [String] {
        paths.filter { FileManager.default.fileExists(atPath: $0) }
    }

    private static func environmentPaths() -> [String]? {
        ProcessInfo.processInfo.environment[EnvironmentKey.claudeConfigDir]
            .map { $0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
    }

    private static func defaultPaths() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/.config/claude",
            "\(home)/.claude"
        ]
    }
}

// MARK: - Terminal Control

private enum Terminal {
    static func hideCursor() {
        print(ANSICode.hideCursor, terminator: "")
    }

    static func showCursor() {
        print(ANSICode.showCursor)
    }

    static func printYellow(_ message: String) {
        print("\(ANSICode.yellow)\(message)\(ANSICode.reset)")
    }
}

// MARK: - Help Text

private enum HelpText {
    static let content = """
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
        """

    static func print() {
        Swift.print(content)
    }
}

// MARK: - Application

private enum Application {
    static func run() async {
        let args = ArgumentParser.parse(CommandLine.arguments)

        if args.shouldShowHelp {
            HelpText.print()
            exit(0)
        }

        guard let paths = validatePaths() else {
            exit(1)
        }

        let (monitor, renderer) = await createComponents(args: args, paths: paths)

        setupGracefulExit()
        Terminal.hideCursor()
        await runLoop(renderer: renderer, interval: args.refreshInterval)
    }

    private static func validatePaths() -> [String]? {
        let candidatePaths = PathDiscovery.discoverClaudePaths()
        let existingPaths = PathDiscovery.filterExisting(candidatePaths)

        guard !existingPaths.isEmpty else {
            print("Error: No Claude data directories found.")
            print("Searched paths:", candidatePaths.joined(separator: ", "))
            return nil
        }

        print("Found Claude data directories:", existingPaths.joined(separator: ", "))
        return existingPaths
    }

    private static func createComponents(
        args: ParsedArguments,
        paths: [String]
    ) async -> (LiveMonitor, LiveRenderer) {
        let config = LiveMonitorConfig(
            claudePaths: paths,
            sessionDurationHours: args.sessionDuration,
            tokenLimit: args.tokenLimit,
            refreshInterval: args.refreshInterval,
            order: .descending
        )

        let monitor = LiveMonitor(config: config)
        let effectiveLimit = await resolveTokenLimit(args.tokenLimit, monitor: monitor)
        let renderer = LiveRenderer(monitor: monitor, tokenLimit: effectiveLimit)

        return (monitor, renderer)
    }

    private static func resolveTokenLimit(_ explicit: Int?, monitor: LiveMonitor) async -> Int? {
        if let explicit { return explicit }

        let autoLimit = await monitor.getAutoTokenLimit()
        if let limit = autoLimit {
            Terminal.printYellow("Using max tokens from previous sessions: \(limit)")
        }
        return autoLimit
    }

    private static func setupGracefulExit() {
        signal(SIGINT) { _ in
            Terminal.showCursor()
            print("\nMonitoring stopped.")
            exit(0)
        }
    }

    private static func runLoop(renderer: LiveRenderer, interval: TimeInterval) async {
        while true {
            await renderer.render()
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
    }
}

// MARK: - Entry Point

Task {
    await Application.run()
}
RunLoop.main.run()
