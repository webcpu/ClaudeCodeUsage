import Foundation
import ClaudeCodeUsage

// Expected daily costs from Claude
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

print("🎯 ClaudeUsageSDK Final Accuracy Test")
print(String(repeating: "=", count: 72))

let client = ClaudeUsageClient(dataSource: .localFiles(basePath: NSHomeDirectory() + "/.claude"))

Task {
    do {
        let stats = try await client.getUsageStats()
        
        print("\n📊 Cost Comparison After Fix:")
        print("┌────────────┬──────────────┬──────────────┬──────────────┬────────┐")
        print("│ Date       │ Expected     │ SDK Actual   │ Difference   │ Status │")
        print("├────────────┼──────────────┼──────────────┼──────────────┼────────┤")
        
        var totalExpected = 0.0
        var totalActual = 0.0
        var accurateCount = 0
        var totalCount = 0
        
        for daily in stats.byDate.sorted(by: { $0.date < $1.date }) {
            if let expected = expectedCosts[daily.date] {
                let actual = daily.totalCost
                let diff = actual - expected
                let percentDiff = abs(diff / expected * 100)
                
                totalExpected += expected
                totalActual += actual
                totalCount += 1
                
                // Consider accurate if within 20% of expected
                let isAccurate = percentDiff <= 20
                if isAccurate {
                    accurateCount += 1
                }
                
                let status = isAccurate ? "✅" : "⚠️"
                
                print(String(format: "│ %-10s │ $%11.2f │ $%11.2f │ %+7.2f (%3.0f%%) │   %s  │",
                            daily.date,
                            expected,
                            actual,
                            diff,
                            percentDiff,
                            status))
            }
        }
        
        print("├────────────┼──────────────┼──────────────┼──────────────┼────────┤")
        
        let totalDiff = totalActual - totalExpected
        let totalPercentDiff = abs(totalDiff / totalExpected * 100)
        
        print(String(format: "│ TOTAL      │ $%11.2f │ $%11.2f │ %+7.2f (%3.0f%%) │        │",
                    totalExpected,
                    totalActual,
                    totalDiff,
                    totalPercentDiff))
        
        print("└────────────┴──────────────┴──────────────┴──────────────┴────────┘")
        
        let accuracy = Double(accurateCount) / Double(totalCount) * 100
        
        print("\n📈 Accuracy Summary:")
        print("   Days within 20% accuracy: \(accurateCount)/\(totalCount) (\(String(format: "%.0f%%", accuracy)))")
        print("   Total cost difference: $\(String(format: "%.2f", totalDiff)) (\(String(format: "%.0f%%", totalPercentDiff)))")
        
        print("\n💡 Notes:")
        print("   • Cache read tokens are excluded from cost calculation")
        print("   • Token counts differ from Claude's display (SDK counts all entries)")
        print("   • Cost calculation uses standard Claude pricing:")
        print("     - Sonnet-4: $3/M input, $15/M output, $3.75/M cache write")
        print("     - Opus-4: $15/M input, $75/M output, $18.75/M cache write")
        
        if accuracy < 80 {
            print("\n⚠️ Accuracy is below 80%. Possible reasons:")
            print("   • Claude may use different aggregation or rounding")
            print("   • Some entries might be filtered in Claude's display")
            print("   • Pricing might have changed over time")
        } else {
            print("\n✅ SDK provides reasonably accurate cost calculations!")
        }
        
    } catch {
        print("❌ Error: \(error)")
    }
    
    exit(0)
}

RunLoop.main.run()
