#!/usr/bin/env swift

import Foundation

// Check if JSONL files have costUSD field
let projectsPath = NSHomeDirectory() + "/.claude/projects"
let targetDate = "2025-07-30"

print("🔍 Checking for costUSD field in JSONL files")
print(String(repeating: "=", count: 72))

var entriesWithCost = 0
var entriesWithoutCost = 0
var totalCostFromField = 0.0

let fileManager = FileManager.default
if let projectDirs = try? fileManager.contentsOfDirectory(atPath: projectsPath) {
    for projectDir in projectDirs.prefix(3) { // Check first 3 projects
        let projectPath = projectsPath + "/" + projectDir
        
        if let files = try? fileManager.contentsOfDirectory(atPath: projectPath) {
            for file in files where file.hasSuffix(".jsonl") {
                let filePath = projectPath + "/" + file
                
                if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
                    let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
                    
                    for line in lines.prefix(10) { // Check first 10 lines
                        if let data = line.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let timestamp = json["timestamp"] as? String {
                            
                            if timestamp.hasPrefix(targetDate) {
                                if let cost = json["costUSD"] as? Double {
                                    entriesWithCost += 1
                                    totalCostFromField += cost
                                    
                                    if entriesWithCost == 1 {
                                        print("\n✅ Found costUSD field!")
                                        print("   Timestamp: \(timestamp)")
                                        print("   Cost: $\(String(format: "%.6f", cost))")
                                        
                                        // Also show the usage data
                                        if let message = json["message"] as? [String: Any],
                                           let usage = message["usage"] as? [String: Any] {
                                            print("   Input: \(usage["input_tokens"] as? Int ?? 0)")
                                            print("   Output: \(usage["output_tokens"] as? Int ?? 0)")
                                            print("   Cache Write: \(usage["cache_creation_input_tokens"] as? Int ?? 0)")
                                            print("   Cache Read: \(usage["cache_read_input_tokens"] as? Int ?? 0)")
                                        }
                                    }
                                } else {
                                    entriesWithoutCost += 1
                                    
                                    if entriesWithoutCost == 1 {
                                        print("\n❌ No costUSD field in entry")
                                        print("   Timestamp: \(timestamp)")
                                        
                                        // Show all fields at top level
                                        print("   Top-level fields: \(json.keys.sorted())")
                                    }
                                }
                            }
                        }
                    }
                }
                
                if entriesWithCost > 0 || entriesWithoutCost > 0 {
                    break // Found what we need
                }
            }
        }
        
        if entriesWithCost > 0 || entriesWithoutCost > 0 {
            break // Found what we need
        }
    }
}

print("\n📊 Summary:")
print("   Entries with costUSD: \(entriesWithCost)")
print("   Entries without costUSD: \(entriesWithoutCost)")
if entriesWithCost > 0 {
    print("   Total cost from field: $\(String(format: "%.2f", totalCostFromField))")
}