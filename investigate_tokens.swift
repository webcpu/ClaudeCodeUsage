#!/usr/bin/env swift

import Foundation

// Check what's actually in the JSONL files for a specific date
let projectsPath = NSHomeDirectory() + "/.claude/projects"
let targetDate = "2025-07-30"

print("🔍 Investigating token counts for \(targetDate)")
print(String(repeating: "=", count: 72))

var totalInput = 0
var totalOutput = 0
var totalCacheWrite = 0
var totalCacheRead = 0
var entryCount = 0

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
                            
                            // Check if this entry is from our target date
                            if timestamp.hasPrefix(targetDate) {
                                if let message = json["message"] as? [String: Any],
                                   let usage = message["usage"] as? [String: Any] {
                                    
                                    let input = usage["input_tokens"] as? Int ?? 0
                                    let output = usage["output_tokens"] as? Int ?? 0
                                    let cacheWrite = usage["cache_creation_input_tokens"] as? Int ?? 0
                                    let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0
                                    
                                    totalInput += input
                                    totalOutput += output
                                    totalCacheWrite += cacheWrite
                                    totalCacheRead += cacheRead
                                    entryCount += 1
                                    
                                    if entryCount <= 3 {
                                        print("\n📝 Sample entry #\(entryCount):")
                                        print("   Timestamp: \(timestamp)")
                                        print("   Model: \(message["model"] as? String ?? "unknown")")
                                        print("   Input: \(input)")
                                        print("   Output: \(output)")
                                        print("   Cache Write: \(cacheWrite)")
                                        print("   Cache Read: \(cacheRead)")
                                        
                                        // Check if there's a costUSD field
                                        if let cost = json["costUSD"] as? Double {
                                            print("   Cost in JSONL: $\(String(format: "%.6f", cost))")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

print("\n📊 Totals for \(targetDate):")
print("   Entries: \(entryCount)")
print("   Input tokens: \(totalInput)")
print("   Output tokens: \(totalOutput)")
print("   Cache write tokens: \(totalCacheWrite)")
print("   Cache read tokens: \(totalCacheRead)")

// Calculate costs with different scenarios
print("\n💰 Cost Calculations:")

// Sonnet-4 pricing
let sonnetInputPrice = 3.0 / 1_000_000
let sonnetOutputPrice = 15.0 / 1_000_000
let sonnetCacheWritePrice = 3.75 / 1_000_000
let sonnetCacheReadPrice = 0.30 / 1_000_000

// Scenario 1: Include all tokens
let cost1 = Double(totalInput) * sonnetInputPrice +
            Double(totalOutput) * sonnetOutputPrice +
            Double(totalCacheWrite) * sonnetCacheWritePrice +
            Double(totalCacheRead) * sonnetCacheReadPrice

print("   With cache tokens: $\(String(format: "%.2f", cost1))")

// Scenario 2: Exclude cache tokens
let cost2 = Double(totalInput) * sonnetInputPrice +
            Double(totalOutput) * sonnetOutputPrice

print("   Without cache tokens: $\(String(format: "%.2f", cost2))")

// Scenario 3: Only cache write (no cache read)
let cost3 = Double(totalInput) * sonnetInputPrice +
            Double(totalOutput) * sonnetOutputPrice +
            Double(totalCacheWrite) * sonnetCacheWritePrice

print("   With cache write only: $\(String(format: "%.2f", cost3))")

print("\n📌 Expected from Claude: $4.00")

// Check if values might be in different units
print("\n🔢 Unit Analysis:")
print("   If table shows thousands:")
print("     Expected input: 420,000 tokens")
print("     Expected output: 15,590,000 tokens")
print("     Cost would be: $\(String(format: "%.2f", 420000 * sonnetInputPrice + 15590000 * sonnetOutputPrice))")

print("\n   Actual tokens found:")
print("     Input: \(totalInput)")
print("     Output: \(totalOutput)")

// Check ratio
if totalInput > 0 && totalOutput > 0 {
    let inputRatio = 420.0 / Double(totalInput)
    let outputRatio = 15590.0 / Double(totalOutput)
    print("\n   Ratios (expected/actual):")
    print("     Input ratio: \(String(format: "%.2f", inputRatio))")
    print("     Output ratio: \(String(format: "%.2f", outputRatio))")
}
