#!/usr/bin/env swift

import Foundation

// Check if Claudia might be storing aggregated data somewhere
let claudePath = NSHomeDirectory() + "/.claude"
let fileManager = FileManager.default

print("🔍 Looking for Claudia's aggregated data source")
print(String(repeating: "=", count: 72))

// Look for JSON files that might contain usage data
func searchForUsageData(in directory: String, level: Int = 0) {
    guard level < 3 else { return }
    
    if let contents = try? fileManager.contentsOfDirectory(atPath: directory) {
        for item in contents {
            if item.hasPrefix(".") { continue }
            
            let itemPath = directory + "/" + item
            var isDirectory: ObjCBool = false
            
            if fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // Skip projects directory as we already know about JSONL files
                    if item != "projects" {
                        searchForUsageData(in: itemPath, level: level + 1)
                    }
                } else if item.hasSuffix(".json") {
                    // Check JSON files for usage data
                    if let data = try? Data(contentsOf: URL(fileURLWithPath: itemPath)),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        
                        // Look for usage-related keys
                        let usageKeys = ["usage", "stats", "cost", "tokens", "daily", "summary"]
                        var foundUsageData = false
                        
                        for key in usageKeys {
                            if json[key] != nil {
                                foundUsageData = true
                                print("\n✅ Found '\(key)' in \(item)")
                                
                                // Check if it contains our dates
                                if let usageData = json[key] {
                                    let dataStr = String(describing: usageData)
                                    if dataStr.contains("2025-07-30") || dataStr.contains("420") || dataStr.contains("15590") {
                                        print("   🎯 Contains matching data!")
                                        print("   File: \(itemPath)")
                                        
                                        // Print a sample of the data
                                        if let prettyData = try? JSONSerialization.data(withJSONObject: json[key]!, options: .prettyPrinted),
                                           let prettyString = String(data: prettyData, encoding: .utf8) {
                                            let lines = prettyString.components(separatedBy: .newlines)
                                            print("   Sample data:")
                                            for line in lines.prefix(20) {
                                                print("     \(line)")
                                            }
                                        }
                                    }
                                }
                                break
                            }
                        }
                        
                        if !foundUsageData && item.lowercased().contains("usage") {
                            print("\n📝 Usage-related file: \(item)")
                            print("   Keys: \(Array(json.keys).prefix(10))")
                        }
                    }
                }
            }
        }
    }
}

searchForUsageData(in: claudePath)

// Check if there's a cache or state file
print("\n\n📦 Checking for cache/state files:")
let possibleCacheLocations = [
    NSHomeDirectory() + "/Library/Caches/com.anthropic.claudia",
    NSHomeDirectory() + "/Library/Application Support/Claudia",
    NSHomeDirectory() + "/.cache/claudia",
    "/tmp/claudia"
]

for location in possibleCacheLocations {
    if fileManager.fileExists(atPath: location) {
        print("   ✅ Found: \(location)")
        
        // List contents
        if let contents = try? fileManager.contentsOfDirectory(atPath: location) {
            for item in contents.prefix(5) {
                print("      - \(item)")
            }
        }
    }
}

// Check environment for any Claudia-specific paths
print("\n\n🌍 Environment variables:")
let env = ProcessInfo.processInfo.environment
for (key, value) in env {
    if key.lowercased().contains("claude") || key.lowercased().contains("usage") {
        print("   \(key) = \(value)")
    }
}

print("\n\n💡 Hypothesis:")
print("   If we can't find pre-aggregated data, Claudia might be:")
print("   1. Calculating on-the-fly with different logic")
print("   2. Using a remote API that returns these values")
print("   3. Applying a transformation we don't know about")
print("   4. Reading from a different session format")