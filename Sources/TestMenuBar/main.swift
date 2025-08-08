//
//  Test Menu Bar Data
//

import Foundation
import ClaudeCodeUsage

print("Testing Menu Bar Today's Cost Feature")
print("=" * 40)

// Create the usage client
let client = ClaudeUsageClient(dataSource: .localFiles(basePath: NSHomeDirectory() + "/.claude"))

// Load usage data
let group = DispatchGroup()
var stats: UsageStats?
var error: Error?

group.enter()
Task {
    do {
        let range = TimeRange.allTime.dateRange
        stats = try await client.getUsageByDateRange(
            startDate: range.start,
            endDate: range.end
        )
    } catch let e {
        error = e
    }
    group.leave()
}

group.wait()

if let error = error {
    print("❌ Error loading data: \(error)")
    exit(1)
}

guard let stats = stats else {
    print("❌ No stats loaded")
    exit(1)
}

// Get today's date string
let formatter = DateFormatter()
formatter.dateFormat = "yyyy-MM-dd"
let todayString = formatter.string(from: Date())

print("\n📅 Today's Date: \(todayString)")
print("\n📊 Overall Statistics:")
print("  • Total Sessions: \(stats.totalSessions)")
print("  • Total Cost: \(stats.totalCost.asCurrency)")
print("  • Days with usage: \(stats.byDate.count)")

// Find today's usage
if let todayUsage = stats.byDate.first(where: { $0.date == todayString }) {
    print("\n✅ Today's Usage Found:")
    print("  • Date: \(todayUsage.date)")
    print("  • Cost: \(todayUsage.totalCost.asCurrency)")
    print("  • Tokens: \(todayUsage.totalTokens.abbreviated)")
    print("  • Models Used: \(todayUsage.modelsUsed.joined(separator: ", "))")
    
    print("\n🎯 Menu Bar Display:")
    print("  💰 \(todayUsage.totalCost.asCurrency)")
} else {
    print("\n⚠️ No usage data for today (\(todayString))")
    print("\n🎯 Menu Bar Display:")
    print("  💰 $0.00")
}

print("\n📋 Recent Daily Usage (last 5 days):")
for daily in stats.byDate.suffix(5) {
    print("  • \(daily.date): \(daily.totalCost.asCurrency)")
}

print("\n" + "=" * 40)
print("✅ Menu bar data test complete!")

// Helper extension
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}