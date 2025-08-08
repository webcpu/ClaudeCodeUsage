import Foundation
import ClaudeCodeUsage

print("🔧 Testing SDK with Deduplication Logic")
print(String(repeating: "=", count: 60))

let client = ClaudiaUsageClient(dataSource: .localFiles(basePath: NSHomeDirectory() + "/.claude"))

do {
    let stats = try await client.getUsageStats()
    
    print("\n📊 SDK Results (with deduplication):")
    print("   Total Cost: $\(String(format: "%.2f", stats.totalCost))")
    print("   Total Sessions: \(stats.totalSessions)")
    print("   Total Tokens: \(stats.totalTokens)")
    print("   Input Tokens: \(stats.totalInputTokens)")
    print("   Output Tokens: \(stats.totalOutputTokens)")
    print("   Cache Write: \(stats.totalCacheCreationTokens)")
    print("   Cache Read: \(stats.totalCacheReadTokens)")
    
    print("\n📅 Daily Breakdown:")
    for daily in stats.byDate.sorted(by: { $0.date < $1.date }) {
        print("   \(daily.date): $\(String(format: "%.2f", daily.totalCost)) - \(daily.totalTokens) tokens")
    }
    
    print("\n✅ Comparison with Claudia's 2025-07-30:")
    print("   Claudia shows: 420 input, 15,590 output, $4.00")
    if let july30 = stats.byDate.first(where: { $0.date == "2025-07-30" }) {
        print("   SDK returns: $\(String(format: "%.2f", july30.totalCost))")
        let match = abs(july30.totalCost - 4.00) < 0.01
        print("   Match: \(match ? "✅" : "❌")")
    } else {
        print("   SDK returns: No data for this date")
    }
    
} catch {
    print("❌ Error: \(error)")
}