import Foundation

// MARK: - Terminal Renderer

public class LiveRenderer {
    private let monitor: LiveMonitor
    private let tokenLimit: Int?

    public init(monitor: LiveMonitor, tokenLimit: Int?) {
        self.monitor = monitor
        self.tokenLimit = tokenLimit
    }

    public func render() async {
        guard let block = await monitor.getActiveBlock() else {
            print("No active session found.")
            return
        }

        let autoLimit = await monitor.getAutoTokenLimit()
        let effectiveLimit = tokenLimit ?? autoLimit ?? 0

        Terminal.clearScreen()
        renderDashboard(block: block, tokenLimit: effectiveLimit)
    }

    private func renderDashboard(block: SessionBlock, tokenLimit: Int) {
        renderHeader()
        renderSection { renderSessionContent(block: block) }
        renderSection { renderUsageContent(block: block, tokenLimit: tokenLimit) }
        renderSection { renderProjectionContent(block: block, tokenLimit: tokenLimit) }
        renderModelsRow(models: block.models)
        renderFooter()
    }
}

// MARK: - Dashboard Layout

private extension LiveRenderer {
    func renderHeader() {
        printBorderRow(.top)
        printContentRow(Layout.title.centered(in: Layout.contentWidth))
        printBorderRow(.middle)
    }

    func renderSection(_ content: () -> Void) {
        printEmptyRow()
        content()
        printEmptyRow()
        printBorderRow(.middle)
    }

    func renderModelsRow(models: [String]) {
        let modelsText = models.joined(separator: ", ")
        let formatted = " \(Layout.modelsIcon)  Models: \(modelsText)"
        printContentRow(formatted.padded(to: Layout.contentWidth))
        printBorderRow(.middle)
    }

    func renderFooter() {
        printContentRow(Layout.footerText.centered(in: Layout.contentWidth))
        printBorderRow(.bottom)
    }
}

// MARK: - Section Content Renderers

private extension LiveRenderer {
    func renderSessionContent(block: SessionBlock) {
        let session = SessionMetrics(block: block)
        let progressBar = ProgressBar.build(
            percentage: session.percentage,
            color: .green
        )
        printContentRow(" \(Layout.sessionIcon)  SESSION  [\(progressBar)]  \(session.percentage.formatted)%")
        printContentRow("   Started: \(session.startTimeFormatted)  Elapsed: \(session.elapsedFormatted)  Remaining: \(session.remainingFormatted) (\(session.endTimeFormatted))")
    }

    func renderUsageContent(block: SessionBlock, tokenLimit: Int) {
        let usage = UsageMetrics(block: block, tokenLimit: tokenLimit)
        let progressBar = ProgressBar.build(
            percentage: usage.percentage,
            color: usage.percentage.progressColor
        )
        printContentRow(" \(Layout.usageIcon)  USAGE    [\(progressBar)]  \(usage.percentage.formatted)% (\(usage.tokensShort)/\(usage.limitShort))")
        printContentRow("   Tokens: \(usage.tokensFormatted)  Burn Rate: \(usage.burnRateFormatted) token/min \(usage.burnIndicator)")
        printContentRow("   Cost: $\(String(format: "%.2f", block.costUSD))")
    }

    func renderProjectionContent(block: SessionBlock, tokenLimit: Int) {
        let projection = ProjectionMetrics(block: block, tokenLimit: tokenLimit)
        let progressBar = ProgressBar.build(
            percentage: projection.percentage,
            color: .red
        )
        printContentRow(" \(Layout.projectionIcon)  PROJECTION [\(progressBar)]  \(projection.percentage.formatted)% (\(projection.tokensShort)/\(projection.limitShort))")
        printContentRow("   Status: \(projection.status)  Tokens: \(projection.tokensFormatted)  Cost: $\(String(format: "%.2f", block.projectedUsage.totalCost))")
    }
}

// MARK: - Print Helpers

private extension LiveRenderer {
    func printBorderRow(_ position: BorderPosition) {
        let (left, right) = position.corners
        print(" \(left)\(Layout.divider)\(right)")
    }

    func printContentRow(_ content: String) {
        print(" \(Layout.verticalBorder)\(content.padded(to: Layout.contentWidth))\(Layout.verticalBorder)")
    }

    func printEmptyRow() {
        printContentRow("")
    }
}

// MARK: - Layout Constants

private enum Layout {
    static let width = 80
    static let contentWidth = width - 2
    static let divider = String(repeating: "\u{2500}", count: contentWidth)
    static let verticalBorder = "\u{2502}"

    static let title = "CLAUDE CODE - LIVE TOKEN USAGE MONITOR"
    static let footerText = "\u{21BB} Refreshing every 1s  \u{2022}  Press Ctrl+C to stop"

    static let sessionIcon = "\u{23F1}\u{FE0F}"
    static let usageIcon = "\u{1F525}"
    static let projectionIcon = "\u{1F4C8}"
    static let modelsIcon = "\u{2699}\u{FE0F}"
}

private enum BorderPosition {
    case top, middle, bottom

    var corners: (String, String) {
        switch self {
        case .top: ("\u{250C}", "\u{2510}")
        case .middle: ("\u{251C}", "\u{2524}")
        case .bottom: ("\u{2514}", "\u{2518}")
        }
    }
}

// MARK: - Terminal Control

private enum Terminal {
    static let clearScreenSequence = "\u{001B}[2J\u{001B}[H"

    static func clearScreen() {
        print(clearScreenSequence, terminator: "")
    }
}

// MARK: - ANSI Colors

private enum ANSIColor: String {
    case red = "\u{001B}[31m"
    case yellow = "\u{001B}[33m"
    case green = "\u{001B}[32m"
    case gray = "\u{001B}[90m"
    case reset = "\u{001B}[0m"

    func wrap(_ text: String) -> String {
        "\(rawValue)\(text)\(ANSIColor.reset.rawValue)"
    }
}

// MARK: - Progress Bar Builder

private enum ProgressBar {
    static let width = 30

    static func build(percentage: Double, color: ANSIColor) -> String {
        let clampedPercentage = min(max(percentage, 0), 100)
        let filled = Int(Double(width) * clampedPercentage / 100)
        let empty = width - filled

        let filledPart = color.wrap(String(repeating: "\u{2588}", count: filled))
        let emptyPart = ANSIColor.gray.wrap(String(repeating: "\u{2591}", count: empty))

        return filledPart + emptyPart
    }
}

// MARK: - Session Metrics

private struct SessionMetrics {
    let percentage: Double
    let startTimeFormatted: String
    let endTimeFormatted: String
    let elapsedFormatted: String
    let remainingFormatted: String

    init(block: SessionBlock) {
        let elapsed = Date().timeIntervalSince(block.startTime)
        let total = block.endTime.timeIntervalSince(block.startTime)
        let remaining = max(0, block.endTime.timeIntervalSince(Date()))

        self.percentage = min((elapsed / total) * 100, 100)
        self.startTimeFormatted = Self.formatTime(block.startTime)
        self.endTimeFormatted = Self.formatTime(block.endTime)
        self.elapsedFormatted = Self.formatDuration(elapsed)
        self.remainingFormatted = Self.formatDuration(remaining)
    }

    private static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date) + " UTC"
    }

    private static func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Usage Metrics

private struct UsageMetrics {
    let percentage: Double
    let tokensFormatted: String
    let tokensShort: String
    let limitShort: String
    let burnRateFormatted: String
    let burnIndicator: String

    init(block: SessionBlock, tokenLimit: Int) {
        let tokens = block.tokenCounts.total
        let burnRate = block.burnRate.tokensPerMinute

        self.percentage = tokenLimit > 0 ? min(Double(tokens) * 100 / Double(tokenLimit), 100) : 0
        self.tokensFormatted = tokens.formattedWithCommas
        self.tokensShort = tokens.formattedShort
        self.limitShort = tokenLimit.formattedShort
        self.burnRateFormatted = burnRate.formattedWithCommas
        self.burnIndicator = Self.burnIndicator(for: burnRate)
    }

    private static func burnIndicator(for rate: Int) -> String {
        switch rate {
        case 500_001...: ANSIColor.red.wrap("\u{26A1} HIGH")
        case 200_001...500_000: ANSIColor.yellow.wrap("\u{26A1} MEDIUM")
        default: ANSIColor.green.wrap("\u{2713} NORMAL")
        }
    }
}

// MARK: - Projection Metrics

private struct ProjectionMetrics {
    let percentage: Double
    let tokensFormatted: String
    let tokensShort: String
    let limitShort: String
    let status: String

    init(block: SessionBlock, tokenLimit: Int) {
        let projectedTokens = block.projectedUsage.totalTokens

        self.percentage = tokenLimit > 0 ? Double(projectedTokens) * 100 / Double(tokenLimit) : 0
        self.tokensFormatted = projectedTokens.formattedWithCommas
        self.tokensShort = projectedTokens.formattedShort
        self.limitShort = tokenLimit.formattedShort
        self.status = Self.status(for: percentage)
    }

    private static func status(for percentage: Double) -> String {
        switch percentage {
        case 100.01...: ANSIColor.red.wrap("\u{274C} WILL EXCEED LIMIT")
        case 90.01...100: ANSIColor.yellow.wrap("\u{26A0}\u{FE0F}  APPROACHING LIMIT")
        default: ANSIColor.green.wrap("\u{2705} WITHIN LIMIT")
        }
    }
}

// MARK: - Number Formatting Extensions

private extension Int {
    var formattedWithCommas: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: self)) ?? String(self)
    }

    var formattedShort: String {
        guard self >= 1000 else { return String(self) }
        return String(format: "%.1fk", Double(self) / 1000.0)
    }
}

private extension Double {
    var formatted: String {
        String(format: "%5.1f", self)
    }

    var progressColor: ANSIColor {
        switch self {
        case 90.01...: .red
        case 75.01...90: .yellow
        default: .green
        }
    }
}

// MARK: - String Formatting Extensions

private extension String {
    func padded(to width: Int) -> String {
        padding(toLength: width, withPad: " ", startingAt: 0)
    }

    func centered(in width: Int) -> String {
        let padding = max(0, width - count)
        let leftPad = padding / 2
        let rightPad = padding - leftPad
        return String(repeating: " ", count: leftPad) + self + String(repeating: " ", count: rightPad)
    }
}
