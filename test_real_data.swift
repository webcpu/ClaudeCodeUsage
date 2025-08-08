#!/usr/bin/env swift

import Foundation

// Direct test without SDK to verify data parsing
let projectsPath = NSHomeDirectory() + "/.claude/projects"
let fileManager = FileManager.default

print("🔍 Direct Data Test")
print(String(repeating: "=", count: 50))

var totalEntries = 0
var totalCost = 0.0

if let projectDirs = try? fileManager.contentsOfDirectory(atPath: projectsPath) {
    print("Found \(projectDirs.count) projects")
    
    for projectDir in projectDirs.prefix(3) { // Check first 3 projects
        let projectPath = projectsPath + "/" + projectDir
        print("\n📁 Project: \(projectDir)")
        
        if let files = try? fileManager.contentsOfDirectory(atPath: projectPath) {
            let jsonlFiles = files.filter { $0.hasSuffix(".jsonl") }
            print("   JSONL files: \(jsonlFiles.count)")
            
            for file in jsonlFiles.prefix(1) { // Check first file
                let filePath = projectPath + "/" + file
                if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
                    let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
                    print("   Lines in \(file): \(lines.count)")
                    
                    var fileEntries = 0
                    for line in lines.prefix(10) { // Check first 10 lines
                        if let data = line.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let message = json["message"] as? [String: Any],
                           let usage = message["usage"] as? [String: Any] {
                            
                            let inputTokens = usage["input_tokens"] as? Int ?? 0
                            let outputTokens = usage["output_tokens"] as? Int ?? 0
                            
                            if inputTokens > 0 || outputTokens > 0 {
                                fileEntries += 1
                                totalEntries += 1
                                
                                let model = message["model"] as? String ?? "unknown"
                                let timestamp = json["timestamp"] as? String ?? ""
                                
                                // Calculate cost
                                let isOpus = model.lowercased().contains("opus")
                                let inputPrice = isOpus ? 15.0/1_000_000 : 3.0/1_000_000
                                let outputPrice = isOpus ? 75.0/1_000_000 : 15.0/1_000_000
                                let cost = Double(inputTokens) * inputPrice + Double(outputTokens) * outputPrice
                                totalCost += cost
                                
                                if fileEntries == 1 {
                                    print("\n   Sample entry:")
                                    print("     Model: \(model)")
                                    print("     Timestamp: \(timestamp)")
                                    print("     Tokens: \(inputTokens) in, \(outputTokens) out")
                                    let costStr = String(format: "%.4f", cost)
                                    print("     Cost: $\(costStr)")
                                }
                            }
                        }
                    }
                    print("   Entries with usage: \(fileEntries)")
                }
            }
        }
    }
}

print("\n📊 Summary:")
print("   Total entries found: \(totalEntries)")
let totalCostStr = String(format: "%.2f", totalCost)
print("   Total cost: $\(totalCostStr)")