#!/usr/bin/env swift

import Foundation

print("🔍 Testing Simple Data Access")
print(String(repeating: "=", count: 50))

let projectsPath = NSHomeDirectory() + "/.claude/projects"
let fileManager = FileManager.default

do {
    guard fileManager.fileExists(atPath: projectsPath) else {
        print("❌ Projects directory not found at: \(projectsPath)")
        exit(1)
    }
    
    let projectDirs = try fileManager.contentsOfDirectory(atPath: projectsPath)
    print("✅ Found \(projectDirs.count) projects")
    
    // Check first project
    if let firstProject = projectDirs.first {
        print("\n📁 First project: \(firstProject)")
        
        // Decode path
        let decodedPath: String
        if firstProject.hasPrefix("-") {
            let pathWithoutLeadingDash = String(firstProject.dropFirst())
            decodedPath = "/" + pathWithoutLeadingDash.replacingOccurrences(of: "-", with: "/")
        } else {
            decodedPath = firstProject.replacingOccurrences(of: "-", with: "/")
        }
        print("   Decoded path: \(decodedPath)")
        
        // Check for JSONL files
        let projectPath = projectsPath + "/" + firstProject
        let files = try fileManager.contentsOfDirectory(atPath: projectPath)
        let jsonlFiles = files.filter { $0.hasSuffix(".jsonl") }
        print("   JSONL files: \(jsonlFiles.count)")
        
        if let firstJsonl = jsonlFiles.first {
            print("   First JSONL: \(firstJsonl)")
            
            // Read first few lines
            let filePath = projectPath + "/" + firstJsonl
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
            print("   Total lines: \(lines.count)")
            
            // Parse first line with usage
            var foundUsage = false
            for line in lines.prefix(20) {
                if let data = line.data(using: .utf8),
                   let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? [String: Any],
                   let usage = message["usage"] as? [String: Any] {
                    
                    let inputTokens = usage["input_tokens"] as? Int ?? 0
                    if inputTokens > 0 {
                        print("\n   ✅ Found usage data:")
                        print("      Model: \(message["model"] as? String ?? "unknown")")
                        print("      Input tokens: \(inputTokens)")
                        print("      Output tokens: \(usage["output_tokens"] as? Int ?? 0)")
                        foundUsage = true
                        break
                    }
                }
            }
            
            if !foundUsage {
                print("   ⚠️ No usage data in first 20 lines")
            }
        }
    }
    
} catch {
    print("❌ Error: \(error)")
    exit(1)
}

print("\n✅ Test complete!")