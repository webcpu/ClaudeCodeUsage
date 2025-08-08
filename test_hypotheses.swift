#!/usr/bin/env swift

import Foundation

// Test different hypotheses about how Claude might be calculating the values
let projectsPath = NSHomeDirectory() + "/.claude/projects"
let targetDate = "2025-07-30"

print("🧪 Testing Hypotheses for Exact Match")
print(String(repeating: "=", count: 72))

var inputTokens = 0
var outputTokens = 0
var cacheWriteTokens = 0
var cacheReadTokens = 0

let fileManager = FileManager.default
if let projectDirs = try? fileManager.contentsOfDirectory(atPath: projectsPath) {
    for projectDir in projectDirs {
        let projectPath = projectsPath + "/" + projectDir
        
        if let files = try? fileManager.contentsOfDirectory(atPath: projectPath) {
            for file in files where file.hasSuffix(".jsonl") {
                let filePath = projectPath + "/" + file
                
                if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
                    let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
                    
                    for line in lines {
                        if let data = line.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let timestamp = json["timestamp"] as? String {
                            
                            if timestamp.hasPrefix(targetDate) {
                                if let message = json["message"] as? [String: Any],
                                   let usage = message["usage"] as? [String: Any] {
                                    
                                    inputTokens += usage["input_tokens"] as? Int ?? 0
                                    outputTokens += usage["output_tokens"] as? Int ?? 0
                                    cacheWriteTokens += usage["cache_creation_input_tokens"] as? Int ?? 0
                                    cacheReadTokens += usage["cache_read_input_tokens"] as? Int ?? 0
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

print("\n📊 Actual token counts for \(targetDate):")
print("   Input: \(inputTokens)")
print("   Output: \(outputTokens)")
print("   Cache Write: \(cacheWriteTokens)")
print("   Cache Read: \(cacheReadTokens)")

print("\n🎯 Expected from Claude:")
print("   Input: 420")
print("   Output: 15,590")
print("   Cost: $4.00")

print("\n🧮 Testing different interpretations:")

// Hypothesis 1: Table shows thousands
print("\n1️⃣ If table values are in thousands:")
print("   420K input = 420,000 tokens")
print("   15,590K output = 15,590,000 tokens")
let cost1 = 420000 * 3.0/1_000_000 + 15590000 * 15.0/1_000_000
print("   Cost would be: $\(String(format: "%.2f", cost1)) ❌ (Expected: $4.00)")

// Hypothesis 2: Table "Input" includes cache write
let combinedInput = inputTokens + cacheWriteTokens
print("\n2️⃣ If 'Input' = input + cache_write:")
print("   Combined input: \(combinedInput)")
print("   Output: \(outputTokens)")
let cost2 = Double(inputTokens) * 3.0/1_000_000 + Double(outputTokens) * 15.0/1_000_000 + Double(cacheWriteTokens) * 3.75/1_000_000
print("   Cost: $\(String(format: "%.2f", cost2))")
if abs(cost2 - 4.00) < 0.5 {
    print("   ✅ Close to expected!")
}

// Hypothesis 3: Values are rounded/scaled
print("\n3️⃣ Check scaling factors:")
let inputScale = 420.0 / Double(inputTokens)
let outputScale = 15590.0 / Double(outputTokens)
print("   Input scale: \(String(format: "%.4f", inputScale))")
print("   Output scale: \(String(format: "%.4f", outputScale))")

// Hypothesis 4: Only counting specific entries
print("\n4️⃣ Reverse engineering from cost:")
print("   If cost is exactly $4.00...")

// Try different token combinations that would give $4.00
// For Sonnet-4: $3/M input, $15/M output, $3.75/M cache write

// If only input and output (no cache):
// 4.00 = input * 3/1M + output * 15/1M
// If output = 15590: 4.00 = input * 3/1M + 15590 * 15/1M
// 4.00 = input * 3/1M + 0.23385
// 3.76615 = input * 3/1M
// input = 1,255,383

// If including cache write at our ratio:
// We have cache_write = 896172, which costs 896172 * 3.75/1M = 3.36
// So remaining for input+output = 4.00 - 3.36 = 0.64

print("   With our cache write (\(cacheWriteTokens)):")
let cacheWriteCost = Double(cacheWriteTokens) * 3.75/1_000_000
print("   Cache write cost: $\(String(format: "%.2f", cacheWriteCost))")
let remainingBudget = 4.00 - cacheWriteCost
print("   Remaining for input+output: $\(String(format: "%.2f", remainingBudget))")

// If we need to get 0.64 from input+output
// And table shows 420 input, 15590 output
// 0.64 = 420 * 3/1M + 15590 * 15/1M
// 0.64 = 0.00126 + 0.23385
// 0.64 ≠ 0.23511 (doesn't match)

// Let's try a different approach - what if the display values are wrong?
print("\n5️⃣ What tokens would give exactly $4.00?")

// Working backwards from $4.00 with our cache write:
let targetCost = 4.00
let actualCacheWriteCost = Double(cacheWriteTokens) * 3.75/1_000_000

// Try proportional scaling
let currentCostNoCache = Double(inputTokens) * 3.0/1_000_000 + Double(outputTokens) * 15.0/1_000_000
let scaleFactor = (targetCost - actualCacheWriteCost) / currentCostNoCache
let scaledInput = Int(Double(inputTokens) * scaleFactor)
let scaledOutput = Int(Double(outputTokens) * scaleFactor)

print("   To get $4.00 with our cache tokens:")
print("   Need input: \(scaledInput)")
print("   Need output: \(scaledOutput)")

// Verification
let verifyCoast = Double(scaledInput) * 3.0/1_000_000 + Double(scaledOutput) * 15.0/1_000_000 + actualCacheWriteCost
print("   Verification: $\(String(format: "%.2f", verifyCoast))")

print("\n🤔 Conclusion:")
if abs(cost2 - 4.00) < 0.3 {
    print("   The SDK calculation ($\(String(format: "%.2f", cost2))) is very close to expected ($4.00)")
    print("   The difference might be due to:")
    print("   • Rounding in Claude's display")
    print("   • Different aggregation timing")
    print("   • Minor calculation differences")
} else {
    print("   There's a significant mismatch that needs investigation")
}
