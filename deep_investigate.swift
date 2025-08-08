#!/usr/bin/env swift

import Foundation

// Deep investigation into the discrepancy
let projectsPath = NSHomeDirectory() + "/.claude/projects"
let targetDate = "2025-07-30"

print("🔬 Deep Investigation: Why don't the numbers match?")
print(String(repeating: "=", count: 72))

struct Entry {
    let timestamp: String
    let sessionId: String
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheWriteTokens: Int
    let cacheReadTokens: Int
    let type: String?
    let role: String?
}

var entries: [Entry] = []
var sessionData: [String: [Entry]] = [:]

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
                    
                    for line in lines {
                        if let data = line.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let timestamp = json["timestamp"] as? String {
                            
                            if timestamp.hasPrefix(targetDate) {
                                let type = json["type"] as? String
                                
                                if let message = json["message"] as? [String: Any] {
                                    let role = message["role"] as? String
                                    
                                    if let usage = message["usage"] as? [String: Any] {
                                        let entry = Entry(
                                            timestamp: timestamp,
                                            sessionId: sessionId,
                                            model: message["model"] as? String ?? "unknown",
                                            inputTokens: usage["input_tokens"] as? Int ?? 0,
                                            outputTokens: usage["output_tokens"] as? Int ?? 0,
                                            cacheWriteTokens: usage["cache_creation_input_tokens"] as? Int ?? 0,
                                            cacheReadTokens: usage["cache_read_input_tokens"] as? Int ?? 0,
                                            type: type,
                                            role: role
                                        )
                                        
                                        entries.append(entry)
                                        
                                        if sessionData[sessionId] == nil {
                                            sessionData[sessionId] = []
                                        }
                                        sessionData[sessionId]?.append(entry)
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

print("\n📊 Raw Data for \(targetDate):")
print("   Total entries with usage: \(entries.count)")
print("   Unique sessions: \(sessionData.count)")

// Analyze entry types
var typeCount: [String: Int] = [:]
var roleCount: [String: Int] = [:]

for entry in entries {
    typeCount[entry.type ?? "nil"] = (typeCount[entry.type ?? "nil"] ?? 0) + 1
    roleCount[entry.role ?? "nil"] = (roleCount[entry.role ?? "nil"] ?? 0) + 1
}

print("\n📝 Entry Types:")
for (type, count) in typeCount.sorted(by: { $0.key < $1.key }) {
    print("   \(type): \(count)")
}

print("\n👤 Message Roles:")
for (role, count) in roleCount.sorted(by: { $0.key < $1.key }) {
    print("   \(role): \(count)")
}

// Calculate totals different ways
print("\n💰 Different Calculation Methods:")

// Method 1: All entries
let totalInput1 = entries.reduce(0) { $0 + $1.inputTokens }
let totalOutput1 = entries.reduce(0) { $0 + $1.outputTokens }
let totalCacheWrite1 = entries.reduce(0) { $0 + $1.cacheWriteTokens }
print("\n1️⃣ All entries:")
print("   Input: \(totalInput1), Output: \(totalOutput1)")
let cost1 = Double(totalInput1) * 3.0/1_000_000 + Double(totalOutput1) * 15.0/1_000_000 + Double(totalCacheWrite1) * 3.75/1_000_000
print("   Cost: $\(String(format: "%.2f", cost1))")

// Method 2: Only assistant responses
let assistantEntries = entries.filter { $0.role == "assistant" }
let totalInput2 = assistantEntries.reduce(0) { $0 + $1.inputTokens }
let totalOutput2 = assistantEntries.reduce(0) { $0 + $1.outputTokens }
let totalCacheWrite2 = assistantEntries.reduce(0) { $0 + $1.cacheWriteTokens }
print("\n2️⃣ Only assistant responses (\(assistantEntries.count) entries):")
print("   Input: \(totalInput2), Output: \(totalOutput2)")
let cost2 = Double(totalInput2) * 3.0/1_000_000 + Double(totalOutput2) * 15.0/1_000_000 + Double(totalCacheWrite2) * 3.75/1_000_000
print("   Cost: $\(String(format: "%.2f", cost2))")

// Method 3: Last entry per session
var lastEntryPerSession: [Entry] = []
for (_, sessionEntries) in sessionData {
    if let lastEntry = sessionEntries.last {
        lastEntryPerSession.append(lastEntry)
    }
}
let totalInput3 = lastEntryPerSession.reduce(0) { $0 + $1.inputTokens }
let totalOutput3 = lastEntryPerSession.reduce(0) { $0 + $1.outputTokens }
let totalCacheWrite3 = lastEntryPerSession.reduce(0) { $0 + $1.cacheWriteTokens }
print("\n3️⃣ Last entry per session (\(lastEntryPerSession.count) entries):")
print("   Input: \(totalInput3), Output: \(totalOutput3)")
let cost3 = Double(totalInput3) * 3.0/1_000_000 + Double(totalOutput3) * 15.0/1_000_000 + Double(totalCacheWrite3) * 3.75/1_000_000
print("   Cost: $\(String(format: "%.2f", cost3))")

// Method 4: Sum per session then total
var sessionTotals: [(input: Int, output: Int, cacheWrite: Int)] = []
for (_, sessionEntries) in sessionData {
    let sessionInput = sessionEntries.reduce(0) { $0 + $1.inputTokens }
    let sessionOutput = sessionEntries.reduce(0) { $0 + $1.outputTokens }
    let sessionCacheWrite = sessionEntries.reduce(0) { $0 + $1.cacheWriteTokens }
    sessionTotals.append((sessionInput, sessionOutput, sessionCacheWrite))
}
let totalInput4 = sessionTotals.reduce(0) { $0 + $1.input }
let totalOutput4 = sessionTotals.reduce(0) { $0 + $1.output }
let totalCacheWrite4 = sessionTotals.reduce(0) { $0 + $1.cacheWrite }
print("\n4️⃣ Sum per session then total:")
print("   Input: \(totalInput4), Output: \(totalOutput4)")
let cost4 = Double(totalInput4) * 3.0/1_000_000 + Double(totalOutput4) * 15.0/1_000_000 + Double(totalCacheWrite4) * 3.75/1_000_000
print("   Cost: $\(String(format: "%.2f", cost4))")

// Check if specific type filtering helps
if let assistantType = typeCount["assistant"] {
    let assistantTypeEntries = entries.filter { $0.type == "assistant" }
    let totalInput5 = assistantTypeEntries.reduce(0) { $0 + $1.inputTokens }
    let totalOutput5 = assistantTypeEntries.reduce(0) { $0 + $1.outputTokens }
    let totalCacheWrite5 = assistantTypeEntries.reduce(0) { $0 + $1.cacheWriteTokens }
    print("\n5️⃣ Only type='assistant' (\(assistantTypeEntries.count) entries):")
    print("   Input: \(totalInput5), Output: \(totalOutput5)")
    let cost5 = Double(totalInput5) * 3.0/1_000_000 + Double(totalOutput5) * 15.0/1_000_000 + Double(totalCacheWrite5) * 3.75/1_000_000
    print("   Cost: $\(String(format: "%.2f", cost5))")
}

print("\n🎯 Expected from Claudia:")
print("   Input: 420, Output: 15,590")
print("   Cost: $4.00")

// Try to match the expected numbers
print("\n🔍 Searching for matching pattern...")

// Check if expected values are in different units
let expectedInput = 420
let expectedOutput = 15590

// Try to find a subset that matches
var bestMatch: (method: String, input: Int, output: Int, cost: Double, diff: Double) = ("", 0, 0, 0, 999999)

let methods = [
    ("All entries", totalInput1, totalOutput1, cost1),
    ("Assistant responses", totalInput2, totalOutput2, cost2),
    ("Last per session", totalInput3, totalOutput3, cost3),
    ("Sum per session", totalInput4, totalOutput4, cost4)
]

for (method, input, output, cost) in methods {
    let diff = abs(cost - 4.00)
    if diff < bestMatch.diff {
        bestMatch = (method, input, output, cost, diff)
    }
}

print("\n✅ Best match:")
print("   Method: \(bestMatch.method)")
print("   Input: \(bestMatch.input), Output: \(bestMatch.output)")
print("   Cost: $\(String(format: "%.2f", bestMatch.cost))")
print("   Difference from expected: $\(String(format: "%.2f", bestMatch.diff))")

// Sample some entries to understand the data
print("\n📋 Sample entries (first 3):")
for entry in entries.prefix(3) {
    print("\n   Timestamp: \(entry.timestamp)")
    print("   Session: \(entry.sessionId)")
    print("   Type: \(entry.type ?? "nil"), Role: \(entry.role ?? "nil")")
    print("   Tokens: I:\(entry.inputTokens) O:\(entry.outputTokens) CW:\(entry.cacheWriteTokens) CR:\(entry.cacheReadTokens)")
}