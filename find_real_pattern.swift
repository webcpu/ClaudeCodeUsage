#!/usr/bin/env swift

import Foundation

// Find the real pattern Claudia uses
let projectsPath = NSHomeDirectory() + "/.claude/projects"
let targetDate = "2025-07-30"

print("🔬 Finding the Real Pattern")
print(String(repeating: "=", count: 72))

// Track different aggregation methods
var perEntryTotal = (input: 0, output: 0, cacheWrite: 0)
var perSessionMax = (input: 0, output: 0, cacheWrite: 0)
var perSessionLast = (input: 0, output: 0, cacheWrite: 0)
var perSessionFirst = (input: 0, output: 0, cacheWrite: 0)
var uniqueModels = Set<String>()

// Session tracking
var sessionData: [String: [(input: Int, output: Int, cacheWrite: Int, timestamp: String)]] = [:]

let fileManager = FileManager.default
if let projectDirs = try? fileManager.contentsOfDirectory(atPath: projectsPath) {
    for projectDir in projectDirs {
        let projectPath = projectsPath + "/" + projectDir
        
        if let files = try? fileManager.contentsOfDirectory(atPath: projectPath) {
            for file in files where file.hasSuffix(".jsonl") {
                let filePath = projectPath + "/" + file
                let sessionId = String(file.dropLast(6))
                
                if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
                    let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
                    
                    var sessionEntries: [(input: Int, output: Int, cacheWrite: Int, timestamp: String)] = []
                    
                    for line in lines {
                        if let data = line.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let timestamp = json["timestamp"] as? String {
                            
                            if timestamp.hasPrefix(targetDate) {
                                if let message = json["message"] as? [String: Any],
                                   let usage = message["usage"] as? [String: Any] {
                                    
                                    let input = usage["input_tokens"] as? Int ?? 0
                                    let output = usage["output_tokens"] as? Int ?? 0
                                    let cacheWrite = usage["cache_creation_input_tokens"] as? Int ?? 0
                                    
                                    if let model = message["model"] as? String {
                                        uniqueModels.insert(model)
                                    }
                                    
                                    // Per entry total
                                    perEntryTotal.input += input
                                    perEntryTotal.output += output
                                    perEntryTotal.cacheWrite += cacheWrite
                                    
                                    sessionEntries.append((input, output, cacheWrite, timestamp))
                                }
                            }
                        }
                    }
                    
                    if !sessionEntries.isEmpty {
                        sessionData[sessionId] = sessionEntries
                        
                        // Max per session
                        let maxInput = sessionEntries.map { $0.input }.max() ?? 0
                        let maxOutput = sessionEntries.map { $0.output }.max() ?? 0
                        let maxCacheWrite = sessionEntries.map { $0.cacheWrite }.max() ?? 0
                        perSessionMax.input += maxInput
                        perSessionMax.output += maxOutput
                        perSessionMax.cacheWrite += maxCacheWrite
                        
                        // Last per session
                        if let last = sessionEntries.last {
                            perSessionLast.input += last.input
                            perSessionLast.output += last.output
                            perSessionLast.cacheWrite += last.cacheWrite
                        }
                        
                        // First per session
                        if let first = sessionEntries.first {
                            perSessionFirst.input += first.input
                            perSessionFirst.output += first.output
                            perSessionFirst.cacheWrite += first.cacheWrite
                        }
                    }
                }
            }
        }
    }
}

print("\n📊 Different Aggregation Methods for \(targetDate):")
print("\n✅ Expected from Claudia:")
print("   Input: 420, Output: 15,590, Cost: $4.00")

// Calculate costs for each method
let sonnetInputPrice = 3.0 / 1_000_000
let sonnetOutputPrice = 15.0 / 1_000_000
let sonnetCacheWritePrice = 3.75 / 1_000_000

print("\n1️⃣ Per Entry Total (what SDK currently does):")
print("   Input: \(perEntryTotal.input), Output: \(perEntryTotal.output)")
let cost1 = Double(perEntryTotal.input) * sonnetInputPrice + 
            Double(perEntryTotal.output) * sonnetOutputPrice + 
            Double(perEntryTotal.cacheWrite) * sonnetCacheWritePrice
print("   Cost: $\(String(format: "%.2f", cost1))")
print("   Match: \(perEntryTotal.input == 420 && perEntryTotal.output == 15590 ? "✅" : "❌")")

print("\n2️⃣ Max per Session:")
print("   Input: \(perSessionMax.input), Output: \(perSessionMax.output)")
let cost2 = Double(perSessionMax.input) * sonnetInputPrice + 
            Double(perSessionMax.output) * sonnetOutputPrice + 
            Double(perSessionMax.cacheWrite) * sonnetCacheWritePrice
print("   Cost: $\(String(format: "%.2f", cost2))")
print("   Match: \(perSessionMax.input == 420 && perSessionMax.output == 15590 ? "✅" : "❌")")

print("\n3️⃣ Last Entry per Session:")
print("   Input: \(perSessionLast.input), Output: \(perSessionLast.output)")
let cost3 = Double(perSessionLast.input) * sonnetInputPrice + 
            Double(perSessionLast.output) * sonnetOutputPrice + 
            Double(perSessionLast.cacheWrite) * sonnetCacheWritePrice
print("   Cost: $\(String(format: "%.2f", cost3))")
print("   Match: \(perSessionLast.input == 420 && perSessionLast.output == 15590 ? "✅" : "❌")")

print("\n4️⃣ First Entry per Session:")
print("   Input: \(perSessionFirst.input), Output: \(perSessionFirst.output)")
let cost4 = Double(perSessionFirst.input) * sonnetInputPrice + 
            Double(perSessionFirst.output) * sonnetOutputPrice + 
            Double(perSessionFirst.cacheWrite) * sonnetCacheWritePrice
print("   Cost: $\(String(format: "%.2f", cost4))")
print("   Match: \(perSessionFirst.input == 420 && perSessionFirst.output == 15590 ? "✅" : "❌")")

print("\n📈 Session Analysis:")
print("   Sessions with data: \(sessionData.count)")
print("   Unique models: \(uniqueModels)")

// Try to find a multiplier or pattern
print("\n🔍 Looking for patterns:")
let expectedInput = 420.0
let expectedOutput = 15590.0

if perEntryTotal.input > 0 && perEntryTotal.output > 0 {
    let inputRatio = expectedInput / Double(perEntryTotal.input)
    let outputRatio = expectedOutput / Double(perEntryTotal.output)
    print("   Scaling factor needed:")
    print("     Input: \(String(format: "%.4f", inputRatio))")
    print("     Output: \(String(format: "%.4f", outputRatio))")
    
    // Check if there's a consistent scaling
    if abs(inputRatio - outputRatio) < 0.1 {
        print("   ✅ Consistent scaling factor: ~\(String(format: "%.2f", (inputRatio + outputRatio) / 2))")
    } else {
        print("   ❌ Different scaling for input and output")
    }
}

// Analyze individual sessions
print("\n📝 Session Details:")
for (sessionId, entries) in sessionData {
    let totalInput = entries.reduce(0) { $0 + $1.input }
    let totalOutput = entries.reduce(0) { $0 + $1.output }
    print("   Session \(sessionId.prefix(8))...")
    print("     Entries: \(entries.count)")
    print("     Total: I:\(totalInput) O:\(totalOutput)")
    if entries.count > 1 {
        print("     First: I:\(entries.first!.input) O:\(entries.first!.output)")
        print("     Last: I:\(entries.last!.input) O:\(entries.last!.output)")
    }
}