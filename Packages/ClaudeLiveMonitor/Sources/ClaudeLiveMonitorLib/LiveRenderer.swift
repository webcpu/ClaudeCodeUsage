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
        
        // Clear screen and move cursor to top
        print("\u{001B}[2J\u{001B}[H", terminator: "")
        
        // Render the dashboard
        renderDashboard(block: block, tokenLimit: effectiveLimit)
    }
    
    private func renderDashboard(block: SessionBlock, tokenLimit: Int) {
        let width = 80
        let divider = String(repeating: "─", count: width - 2)
        
        // Header
        print(" ┌\(divider)┐")
        print(" │\(center("CLAUDE CODE - LIVE TOKEN USAGE MONITOR", width: width - 2))│")
        print(" ├\(divider)┤")
        
        // Session section
        print(" │\(String(repeating: " ", count: width - 2))│")
        renderSessionSection(block: block, width: width)
        print(" │\(String(repeating: " ", count: width - 2))│")
        print(" ├\(divider)┤")
        
        // Usage section
        print(" │\(String(repeating: " ", count: width - 2))│")
        renderUsageSection(block: block, tokenLimit: tokenLimit, width: width)
        print(" │\(String(repeating: " ", count: width - 2))│")
        print(" ├\(divider)┤")
        
        // Projection section
        print(" │\(String(repeating: " ", count: width - 2))│")
        renderProjectionSection(block: block, tokenLimit: tokenLimit, width: width)
        print(" │\(String(repeating: " ", count: width - 2))│")
        print(" ├\(divider)┤")
        
        // Models section
        let modelsText = block.models.joined(separator: ", ")
        print(" │ ⚙️  Models: \(modelsText.padding(toLength: width - 15, withPad: " ", startingAt: 0))│")
        print(" ├\(divider)┤")
        
        // Footer
        print(" │\(center("↻ Refreshing every 1s  •  Press Ctrl+C to stop", width: width - 2))│")
        print(" └\(divider)┘")
    }
    
    private func renderSessionSection(block: SessionBlock, width: Int) {
        let elapsed = Date().timeIntervalSince(block.startTime)
        let total = block.endTime.timeIntervalSince(block.startTime)
        let percentage = min((elapsed / total) * 100, 100)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        let startStr = formatter.string(from: block.startTime) + " UTC"
        let endStr = formatter.string(from: block.endTime) + " UTC"
        
        let elapsedHours = Int(elapsed / 3600)
        let elapsedMinutes = Int((elapsed.truncatingRemainder(dividingBy: 3600)) / 60)
        let remainingTime = max(0, block.endTime.timeIntervalSince(Date()))
        let remainingHours = Int(remainingTime / 3600)
        let remainingMinutes = Int((remainingTime.truncatingRemainder(dividingBy: 3600)) / 60)
        
        // Progress bar
        let barWidth = 30
        let filled = Int(Double(barWidth) * percentage / 100)
        let empty = barWidth - filled
        let progressBar = "\u{001B}[32m" + String(repeating: "█", count: filled) + "\u{001B}[0m" +
                         "\u{001B}[90m" + String(repeating: "░", count: empty) + "\u{001B}[0m"
        
        print(" │ ⏱️  SESSION  [\(progressBar)]  \(String(format: "%5.1f%%", percentage))│")
        print(" │   Started: \(startStr)  Elapsed: \(elapsedHours)h \(elapsedMinutes)m  Remaining: \(remainingHours)h \(remainingMinutes)m (\(endStr))│")
    }
    
    private func renderUsageSection(block: SessionBlock, tokenLimit: Int, width: Int) {
        let tokens = block.tokenCounts.total
        let percentage = tokenLimit > 0 ? min(Double(tokens) * 100 / Double(tokenLimit), 100) : 0
        
        // Progress bar
        let barWidth = 30
        let filled = Int(Double(barWidth) * percentage / 100)
        let empty = barWidth - filled
        
        let barColor = percentage > 90 ? "\u{001B}[31m" : // Red
                       percentage > 75 ? "\u{001B}[33m" : // Yellow
                       "\u{001B}[32m" // Green
        
        let progressBar = barColor + String(repeating: "█", count: filled) + "\u{001B}[0m" +
                         "\u{001B}[90m" + String(repeating: "░", count: empty) + "\u{001B}[0m"
        
        let burnRateStr = formatBurnRate(block.burnRate.tokensPerMinute)
        let burnIndicator = block.burnRate.tokensPerMinute > 500000 ? "\u{001B}[31m⚡ HIGH\u{001B}[0m" :
                           block.burnRate.tokensPerMinute > 200000 ? "\u{001B}[33m⚡ MEDIUM\u{001B}[0m" :
                           "\u{001B}[32m✓ NORMAL\u{001B}[0m"
        
        print(" │ 🔥  USAGE    [\(progressBar)]  \(String(format: "%5.1f%%", percentage)) (\(formatTokensShort(tokens))/\(formatTokensShort(tokenLimit)))│")
        print(" │   Tokens: \(formatTokens(tokens))  Burn Rate: \(burnRateStr) token/min \(burnIndicator)│")
        print(" │   Cost: $\(String(format: "%.2f", block.costUSD))│")
    }
    
    private func renderProjectionSection(block: SessionBlock, tokenLimit: Int, width: Int) {
        let projectedTokens = block.projectedUsage.totalTokens
        let percentage = tokenLimit > 0 ? Double(projectedTokens) * 100 / Double(tokenLimit) : 0
        
        // Progress bar
        let barWidth = 30
        let filled = min(Int(Double(barWidth) * percentage / 100), barWidth)
        let empty = max(0, barWidth - filled)
        
        let progressBar = "\u{001B}[31m" + String(repeating: "█", count: filled) + "\u{001B}[0m" +
                         "\u{001B}[90m" + String(repeating: "░", count: empty) + "\u{001B}[0m"
        
        let status = percentage > 100 ? "\u{001B}[31m❌ WILL EXCEED LIMIT\u{001B}[0m" :
                    percentage > 90 ? "\u{001B}[33m⚠️  APPROACHING LIMIT\u{001B}[0m" :
                    "\u{001B}[32m✅ WITHIN LIMIT\u{001B}[0m"
        
        print(" │ 📈  PROJECTION [\(progressBar)]  \(String(format: "%5.1f%%", percentage)) (\(formatTokensShort(projectedTokens))/\(formatTokensShort(tokenLimit)))│")
        print(" │   Status: \(status)  Tokens: \(formatTokens(projectedTokens))  Cost: $\(String(format: "%.2f", block.projectedUsage.totalCost))│")
    }
    
    // MARK: - Formatting Helpers
    
    private func formatTokens(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: num)) ?? String(num)
    }
    
    private func formatTokensShort(_ num: Int) -> String {
        if num >= 1000 {
            let thousands = Double(num) / 1000.0
            return String(format: "%.1fk", thousands)
        }
        return String(num)
    }
    
    private func formatBurnRate(_ rate: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: rate)) ?? String(rate)
    }
    
    private func center(_ text: String, width: Int) -> String {
        let padding = max(0, width - text.count)
        let leftPad = padding / 2
        let rightPad = padding - leftPad
        return String(repeating: " ", count: leftPad) + text + String(repeating: " ", count: rightPad)
    }
}
