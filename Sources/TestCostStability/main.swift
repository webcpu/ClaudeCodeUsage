import Foundation
import ClaudeCodeUsage

// Test script to verify cost stability after race condition fix
func testCostStability() async {
    print("Testing Cost Stability with Race Condition Fix")
    print("=" * 50)
    
    let client = ClaudeUsageClient(dataSource: .localFiles(basePath: NSHomeDirectory() + "/.claude"))
    
    // Perform multiple rapid data loads to test consistency
    var costValues: [Double] = []
    var sessionCounts: [Int] = []
    
    for i in 1...10 {
        print("\nLoad attempt #\(i):")
        
        do {
            let range = TimeRange.allTime.dateRange
            let stats = try await client.getUsageByDateRange(
                startDate: range.start,
                endDate: range.end
            )
            
            // Get today's cost
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let todayString = formatter.string(from: Date())
            
            var todaysCost = 0.0
            if let todayUsage = stats.byDate.first(where: { $0.date == todayString }) {
                todaysCost = todayUsage.totalCost
            }
            
            costValues.append(todaysCost)
            sessionCounts.append(stats.totalSessions)
            
            print("  Sessions: \(stats.totalSessions)")
            print("  Today's cost: $\(String(format: "%.2f", todaysCost))")
            print("  Total cost: $\(String(format: "%.2f", stats.totalCost))")
        } catch {
            print("  Error loading: \(error)")
        }
        
        // Small delay between loads
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
    }
    
    print("\n" + "=" * 50)
    print("Stability Analysis:")
    
    // Check if all values are consistent
    let uniqueCosts = Set(costValues)
    let uniqueSessions = Set(sessionCounts)
    
    if uniqueCosts.count == 1 && uniqueSessions.count == 1 {
        print("✅ SUCCESS: All values are STABLE!")
        print("  Consistent cost: $\(String(format: "%.2f", costValues.first ?? 0))")
        print("  Consistent sessions: \(sessionCounts.first ?? 0)")
    } else {
        print("⚠️  Values show some variation:")
        print("  Unique cost values: \(uniqueCosts.count)")
        if uniqueCosts.count > 1 {
            print("  Cost values: \(costValues.map { String(format: "%.2f", $0) }.joined(separator: ", "))")
        }
        print("  Unique session counts: \(uniqueSessions.count)")
        if uniqueSessions.count > 1 {
            print("  Session counts: \(sessionCounts)")
        }
    }
    
    // Test concurrent loads
    print("\n" + "=" * 50)
    print("Testing Concurrent Loads:")
    
    async let load1 = client.getUsageByDateRange(
        startDate: TimeRange.allTime.dateRange.start,
        endDate: TimeRange.allTime.dateRange.end
    )
    async let load2 = client.getUsageByDateRange(
        startDate: TimeRange.allTime.dateRange.start,
        endDate: TimeRange.allTime.dateRange.end
    )
    async let load3 = client.getUsageByDateRange(
        startDate: TimeRange.allTime.dateRange.start,
        endDate: TimeRange.allTime.dateRange.end
    )
    
    do {
        let stats1 = try await load1
        let stats2 = try await load2
        let stats3 = try await load3
        
        print("✅ Concurrent loads completed successfully")
        print("  Load 1: \(stats1.totalSessions) sessions, $\(String(format: "%.2f", stats1.totalCost))")
        print("  Load 2: \(stats2.totalSessions) sessions, $\(String(format: "%.2f", stats2.totalCost))")
        print("  Load 3: \(stats3.totalSessions) sessions, $\(String(format: "%.2f", stats3.totalCost))")
        
        if stats1.totalSessions == stats2.totalSessions && stats2.totalSessions == stats3.totalSessions {
            print("✅ All concurrent loads returned identical results!")
        } else {
            print("⚠️  Concurrent loads returned different results")
        }
    } catch {
        print("❌ Error during concurrent loads: \(error)")
    }
}

// Helper to repeat string
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}

// Run the test
Task {
    await testCostStability()
    print("\n✅ Test completed!")
    exit(0)
}

RunLoop.main.run()