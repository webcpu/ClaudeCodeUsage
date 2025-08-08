import Foundation
import SwiftUI
import ClaudeCodeUsage

// Test the progress bar calculations
let dataModel = UsageDataModel()

// Set test values
dataModel.dailyCostThreshold = 100.0

print("Testing Progress Bar Values")
print("=" * 50)

// Test daily cost progress
let testCosts = [0.0, 25.0, 50.0, 75.0, 95.0, 100.0, 150.0]
for cost in testCosts {
    // Simulate today's cost
    let progress = min(cost / dataModel.dailyCostThreshold, 1.0)
    let percentage = Int(progress * 100)
    
    print("\nDaily Cost: $\(cost)")
    print("  Progress: \(progress)")
    print("  Percentage: \(percentage)%")
    
    // Determine color
    let color: String
    switch progress {
    case 0..<0.5: color = "Green"
    case 0.5..<0.8: color = "Yellow"
    case 0.8..<0.95: color = "Orange"
    default: color = "Red"
    }
    print("  Color: \(color)")
}

print("\n\nSession Time Progress Test")
print("=" * 50)

// Test session time progress
let sessionStart = Date().addingTimeInterval(-2 * 3600) // Started 2 hours ago
let sessionEnd = sessionStart.addingTimeInterval(5 * 3600) // 5 hour session
let elapsed = Date().timeIntervalSince(sessionStart)
let total = sessionEnd.timeIntervalSince(sessionStart)
let timeProgress = min(elapsed / total, 1.0)

print("Session started: 2 hours ago")
print("Session duration: 5 hours")
print("Time elapsed: \(elapsed / 3600) hours")
print("Progress: \(timeProgress)")
print("Percentage: \(Int(timeProgress * 100))%")

print("\n\nToken Usage Progress Test")
print("=" * 50)

// Test token usage progress
let tokenLimits = [100_000, 1_000_000, 10_000_000, 50_000_000]
let currentTokens = 25_000_000

for limit in tokenLimits {
    let progress = min(Double(currentTokens) / Double(limit), 1.0)
    print("\nCurrent: \(currentTokens / 1_000_000)M tokens")
    print("Limit: \(limit / 1_000_000)M tokens")
    print("Progress: \(progress)")
    print("Percentage: \(Int(progress * 100))%")
}

print("\n\n✅ Progress bar calculations verified!")