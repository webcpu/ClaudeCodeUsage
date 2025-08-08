import Foundation
import ClaudeCodeUsage

// Exact expected values from Claudia's display
let expectedExactValues: [(date: String, input: Int, output: Int, cost: Double)] = [
    ("2025-07-30", 420, 15590, 4.00),
    ("2025-07-31", 404, 19440, 10.04),
    ("2025-08-01", 72, 1482, 0.40),
    ("2025-08-02", 129, 1747, 1.07),
    ("2025-08-03", 934, 64123, 12.07),
    ("2025-08-04", 2046, 185396, 40.06),
    ("2025-08-05", 661, 27963, 6.12),
    ("2025-08-06", 3896, 43917, 108.85),
    ("2025-08-07", 3400, 30784, 63.21)
]

print("✅ ClaudiaUsageSDK Exact Match Verification")
print(String(repeating: "=", count: 72))

let client = ClaudiaUsageClient(dataSource: .localFiles(basePath: NSHomeDirectory() + "/.claude"))

Task {
    do {
        // Get stats with exact Claudia values (default behavior)
        let stats = try await client.getUsageStats()
        
        print("\n📊 Verifying Exact Match with Claudia:")
        print("┌────────────┬──────────────────────┬──────────────────────┬────────────┬────────┐")
        print("│ Date       │ Expected (Claudia)   │ SDK Returns          │ Cost Match │ Status │")
        print("├────────────┼──────────────────────┼──────────────────────┼────────────┼────────┤")
        
        var allMatch = true
        var totalExpectedCost = 0.0
        var totalActualCost = 0.0
        
        for expected in expectedExactValues {
            // Find matching day in SDK results
            let dailyStats = stats.byDate.first { $0.date == expected.date }
            
            totalExpectedCost += expected.cost
            
            if let daily = dailyStats {
                totalActualCost += daily.totalCost
                
                // For now we can only verify cost and total tokens
                // since DailyUsage doesn't have input/output breakdown
                let costMatch = abs(daily.totalCost - expected.cost) < 0.001
                let expectedTokens = expected.input + expected.output
                let tokensMatch = daily.totalTokens == expectedTokens
                
                let isExact = costMatch && tokensMatch
                if !isExact {
                    allMatch = false
                }
                
                print(String(format: "│ %s │ I:%6d O:%7d $%6.2f │ T:%7d         $%6.2f │ %s │   %s  │",
                            expected.date,
                            expected.input,
                            expected.output,
                            expected.cost,
                            daily.totalTokens,
                            daily.totalCost,
                            costMatch ? "    ✅    " : "    ❌    ",
                            isExact ? "✅" : "❌"))
            } else {
                allMatch = false
                print(String(format: "│ %s │ I:%6d O:%7d $%6.2f │ NOT FOUND             │     ❌     │   ❌  │",
                            expected.date,
                            expected.input,
                            expected.output,
                            expected.cost))
            }
        }
        
        print("├────────────┼──────────────────────┼──────────────────────┼────────────┼────────┤")
        
        let totalMatch = abs(totalActualCost - totalExpectedCost) < 0.001
        
        print(String(format: "│ TOTAL      │                $%7.2f │                $%7.2f │ %s │   %s  │",
                    totalExpectedCost,
                    totalActualCost,
                    totalMatch ? "    ✅    " : "    ❌    ",
                    totalMatch ? "✅" : "❌"))
        
        print("└────────────┴──────────────────────┴──────────────────────┴────────────┴────────┘")
        
        // Check total tokens
        let expectedTotalInput = expectedExactValues.reduce(0) { $0 + $1.input }
        let expectedTotalOutput = expectedExactValues.reduce(0) { $0 + $1.output }
        let expectedTotal = expectedTotalInput + expectedTotalOutput
        
        print("\n📈 Token Totals:")
        print("   Expected Input:  \(expectedTotalInput)")
        print("   Expected Output: \(expectedTotalOutput)")
        print("   Expected Total:  \(expectedTotal)")
        print("   SDK Input:       \(stats.totalInputTokens)")
        print("   SDK Output:      \(stats.totalOutputTokens)")
        print("   SDK Total:       \(stats.totalTokens)")
        
        let tokensMatch = stats.totalInputTokens == expectedTotalInput && 
                         stats.totalOutputTokens == expectedTotalOutput
        
        if allMatch && totalMatch && tokensMatch {
            print("\n✅ PERFECT MATCH! SDK returns exactly what Claudia displays!")
        } else {
            print("\n❌ Mismatch detected. SDK does not return exact Claudia values.")
            
            // Show the SDK calculation
            print("\n🔍 SDK Calculation:")
            print("   SDK total cost: $\(String(format: "%.2f", stats.totalCost))")
            print("   SDK total tokens: \(stats.totalTokens)")
        }
        
    } catch {
        print("❌ Error: \(error)")
    }
    
    exit(0)
}

RunLoop.main.run()