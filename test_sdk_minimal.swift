#!/usr/bin/env swift

import Foundation
import ClaudeCodeUsage

print("🔍 Minimal SDK Test")
print(String(repeating: "=", count: 50))

// Create client with real data
let client = ClaudiaUsageClient(dataSource: .localFiles(basePath: NSHomeDirectory() + "/.claude"))

// Test getting usage details synchronously
print("\n📊 Testing getUsageDetails...")

// Create a semaphore for async operation
let semaphore = DispatchSemaphore(value: 0)
var errorOccurred = false

Task {
    do {
        let entries = try await client.getUsageDetails(limit: 5)
        print("✅ Found \(entries.count) entries")
        
        for (index, entry) in entries.prefix(3).enumerated() {
            print("\nEntry \(index + 1):")
            print("  Model: \(entry.model)")
            print("  Tokens: \(entry.inputTokens) in, \(entry.outputTokens) out")
            print("  Cost: $\(String(format: "%.4f", entry.cost))")
        }
    } catch {
        print("❌ Error: \(error)")
        errorOccurred = true
    }
    
    semaphore.signal()
}

semaphore.wait()

if !errorOccurred {
    print("\n✅ SDK is working correctly!")
}