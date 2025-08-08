import Foundation
import ClaudeCodeUsage

// Expected daily costs from Claudia
let expectedCosts: [String: Double] = [
    "2025-07-30": 4.00,
    "2025-07-31": 10.04,
    "2025-08-01": 0.40,
    "2025-08-02": 1.07,
    "2025-08-03": 12.07,
    "2025-08-04": 40.06,
    "2025-08-05": 6.12,
    "2025-08-06": 108.85,
    "2025-08-07": 63.21
]

print("🔍 Debugging ClaudiaUsageSDK Cost Calculations")
print(String(repeating: "=", count: 72))

let claudePath = NSHomeDirectory() + "/.claude"
let client = ClaudiaUsageClient(dataSource: .localFiles(basePath: claudePath))

Task {
    do {
        // Get all entries for detailed analysis
        let entries = try await client.getUsageDetails(limit: nil)
        print("📊 Found \(entries.count) total entries")
        
        // Group by date and calculate costs
        var dailyCosts: [String: (inputTokens: Int, outputTokens: Int, cacheWriteTokens: Int, cacheReadTokens: Int, cost: Double, models: Set<String>)] = [:]
        
        for entry in entries {
            if let date = entry.date {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let dateStr = formatter.string(from: date)
                
                var current = dailyCosts[dateStr] ?? (0, 0, 0, 0, 0.0, Set<String>())
                current.inputTokens += entry.inputTokens
                current.outputTokens += entry.outputTokens
                current.cacheWriteTokens += entry.cacheWriteTokens
                current.cacheReadTokens += entry.cacheReadTokens
                current.cost += entry.cost
                current.models.insert(entry.model)
                dailyCosts[dateStr] = current
            }
        }
        
        // Get aggregated stats for comparison
        let stats = try await client.getUsageStats()
        
        print("\n📅 Daily Cost Comparison:")
        print("┌────────────┬──────────────┬──────────────┬──────────────┐")
        print("│ Date       │ Expected     │ SDK Actual   │ Difference   │")
        print("├────────────┼──────────────┼──────────────┼──────────────┤")
        
        var totalExpected = 0.0
        var totalActual = 0.0
        
        for date in expectedCosts.keys.sorted() {
            let expected = expectedCosts[date]!
            let actual = dailyCosts[date]?.cost ?? 0.0
            let diff = actual - expected
            
            totalExpected += expected
            totalActual += actual
            
            let status = abs(diff) < 0.01 ? "✅" : "❌"
            
            print(String(format: "│ %-10s │ $%11.2f │ $%11.2f │ %+11.2f %s │",
                        date,
                        expected,
                        actual,
                        diff,
                        status))
            
            // Show token details for days with discrepancies
            if abs(diff) >= 0.01, let dayData = dailyCosts[date] {
                print("│            │ Input tokens: \(dayData.inputTokens)")
                print("│            │ Output tokens: \(dayData.outputTokens)")
                print("│            │ Cache write: \(dayData.cacheWriteTokens)")
                print("│            │ Cache read: \(dayData.cacheReadTokens)")
                print("│            │ Models: \(dayData.models.joined(separator: ", "))")
                
                // Recalculate cost manually
                var recalcCost = 0.0
                for model in dayData.models {
                    if let pricing = ModelPricing.pricing(for: model) {
                        let modelEntries = entries.filter { entry in
                            if let entryDate = entry.date {
                                let formatter = DateFormatter()
                                formatter.dateFormat = "yyyy-MM-dd"
                                return formatter.string(from: entryDate) == date && entry.model == model
                            }
                            return false
                        }
                        
                        let modelInput = modelEntries.reduce(0) { $0 + $1.inputTokens }
                        let modelOutput = modelEntries.reduce(0) { $0 + $1.outputTokens }
                        let modelCacheWrite = modelEntries.reduce(0) { $0 + $1.cacheWriteTokens }
                        let modelCacheRead = modelEntries.reduce(0) { $0 + $1.cacheReadTokens }
                        
                        let modelCost = pricing.calculateCost(
                            inputTokens: modelInput,
                            outputTokens: modelOutput,
                            cacheWriteTokens: modelCacheWrite,
                            cacheReadTokens: modelCacheRead
                        )
                        
                        recalcCost += modelCost
                        
                        print("│            │ \(model.components(separatedBy: "-").prefix(2).joined(separator: "-")): $\(String(format: "%.2f", modelCost))")
                    }
                }
                print("│            │ Recalculated total: $\(String(format: "%.2f", recalcCost))")
            }
        }
        
        print("├────────────┼──────────────┼──────────────┼──────────────┤")
        print(String(format: "│ TOTAL      │ $%11.2f │ $%11.2f │ %+11.2f     │",
                    totalExpected,
                    totalActual,
                    totalActual - totalExpected))
        print("└────────────┴──────────────┴──────────────┴──────────────┘")
        
        // Check stats.byDate as well
        print("\n📊 SDK Stats byDate Comparison:")
        for daily in stats.byDate.sorted(by: { $0.date < $1.date }) {
            let expected = expectedCosts[daily.date] ?? 0.0
            let diff = daily.totalCost - expected
            let status = abs(diff) < 0.01 ? "✅" : "❌"
            
            print(String(format: "%s: Expected $%.2f, Got $%.2f (diff: %+.2f) %s",
                        daily.date,
                        expected,
                        daily.totalCost,
                        diff,
                        status))
        }
        
        // Sample a few entries to check individual cost calculations
        print("\n🔬 Sample Entry Analysis (first 5 entries):")
        for entry in entries.prefix(5) {
            if let date = entry.date {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                
                print("\n📝 Entry: \(formatter.string(from: date))")
                print("   Model: \(entry.model)")
                print("   Input: \(entry.inputTokens), Output: \(entry.outputTokens)")
                print("   Cache Write: \(entry.cacheWriteTokens), Cache Read: \(entry.cacheReadTokens)")
                print("   Cost in entry: $\(String(format: "%.6f", entry.cost))")
                
                // Recalculate
                if let pricing = ModelPricing.pricing(for: entry.model) {
                    let recalc = pricing.calculateCost(
                        inputTokens: entry.inputTokens,
                        outputTokens: entry.outputTokens,
                        cacheWriteTokens: entry.cacheWriteTokens,
                        cacheReadTokens: entry.cacheReadTokens
                    )
                    print("   Recalculated: $\(String(format: "%.6f", recalc))")
                    if abs(recalc - entry.cost) > 0.000001 {
                        print("   ⚠️ Cost mismatch!")
                    }
                }
            }
        }
        
    } catch {
        print("❌ Error: \(error)")
    }
    
    exit(0)
}

RunLoop.main.run()