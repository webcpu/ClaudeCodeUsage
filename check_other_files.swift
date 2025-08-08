#!/usr/bin/env swift

import Foundation

// Check if there are other files that might contain the usage data
let claudePath = NSHomeDirectory() + "/.claude"

print("🔍 Checking for other data files in ~/.claude")
print(String(repeating: "=", count: 72))

let fileManager = FileManager.default

// Check for different file types
var foundFiles: [String: [String]] = [:]

func scanDirectory(at path: String, level: Int = 0) {
    guard level < 3 else { return } // Limit depth
    
    if let contents = try? fileManager.contentsOfDirectory(atPath: path) {
        for item in contents {
            let itemPath = path + "/" + item
            
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    if !item.hasPrefix(".") && item != "projects" {
                        scanDirectory(at: itemPath, level: level + 1)
                    }
                } else {
                    let ext = (item as NSString).pathExtension.lowercased()
                    if ext != "jsonl" && !item.hasPrefix(".") {
                        if foundFiles[ext] == nil {
                            foundFiles[ext] = []
                        }
                        foundFiles[ext]?.append(itemPath)
                    }
                }
            }
        }
    }
}

scanDirectory(at: claudePath)

print("\n📁 Found file types:")
for (ext, files) in foundFiles.sorted(by: { $0.key < $1.key }) {
    print("   .\(ext.isEmpty ? "(no extension)" : ext): \(files.count) files")
    if files.count <= 3 {
        for file in files {
            print("      - \(file)")
        }
    }
}

// Check for specific files that might contain usage data
let possibleFiles = [
    claudePath + "/usage.json",
    claudePath + "/stats.json",
    claudePath + "/usage.db",
    claudePath + "/claude.db",
    claudePath + "/data.json"
]

print("\n📊 Checking for specific usage files:")
for file in possibleFiles {
    if fileManager.fileExists(atPath: file) {
        print("   ✅ Found: \(file)")
        
        // Try to read if it's JSON
        if file.hasSuffix(".json") {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: file)),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("      Keys: \(json.keys.sorted())")
            }
        }
    } else {
        print("   ❌ Not found: \(file)")
    }
}

// Check if there's a config or state file
print("\n⚙️ Looking for config/state files:")
let configPaths = [
    claudePath + "/config.json",
    claudePath + "/state.json",
    claudePath + "/settings.json"
]

for path in configPaths {
    if fileManager.fileExists(atPath: path) {
        print("   ✅ Found: \(path)")
        
        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("      Keys: \(json.keys.sorted().prefix(10))")
            
            // Check if there's usage data
            if json["usage"] != nil {
                print("      🎯 Contains 'usage' key!")
            }
            if json["stats"] != nil {
                print("      🎯 Contains 'stats' key!")
            }
        }
    }
}

// Check the structure of a JSONL file more carefully
print("\n📝 Analyzing JSONL structure:")
if let projectDirs = try? fileManager.contentsOfDirectory(atPath: claudePath + "/projects"),
   let firstProject = projectDirs.first {
    let projectPath = claudePath + "/projects/" + firstProject
    
    if let files = try? fileManager.contentsOfDirectory(atPath: projectPath),
       let jsonlFile = files.first(where: { $0.hasSuffix(".jsonl") }) {
        
        let filePath = projectPath + "/" + jsonlFile
        print("   Checking: \(jsonlFile)")
        
        if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
            let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            print("   Total lines: \(lines.count)")
            
            // Check different line types
            var lineTypes: Set<String> = []
            var hasCostField = false
            
            for line in lines.prefix(50) {
                if let data = line.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    if let type = json["type"] as? String {
                        lineTypes.insert(type)
                    }
                    
                    if json["costUSD"] != nil || json["cost"] != nil {
                        hasCostField = true
                    }
                }
            }
            
            print("   Line types found: \(lineTypes.sorted())")
            print("   Has cost field: \(hasCostField)")
        }
    }
}