import Foundation
import ClaudeCodeUsage

print("🚀 Claudia Usage Dashboard - Synchronous Test")
print(String(repeating: "=", count: 72))

// Direct synchronous parsing test
let projectsPath = NSHomeDirectory() + "/.claude/projects"
let fileManager = FileManager.default

var allEntries: [UsageEntry] = []

if let projectDirs = try? fileManager.contentsOfDirectory(atPath: projectsPath) {
    print("📁 Found \(projectDirs.count) projects")
    
    for projectDir in projectDirs.prefix(3) {
        let projectPath = projectsPath + "/" + projectDir
        
        // Decode project path
        let decodedPath: String
        if projectDir.hasPrefix("-") {
            let pathWithoutLeadingDash = String(projectDir.dropFirst())
            decodedPath = "/" + pathWithoutLeadingDash.replacingOccurrences(of: "-", with: "/")
        } else {
            decodedPath = projectDir.replacingOccurrences(of: "-", with: "/")
        }
        
        if let files = try? fileManager.contentsOfDirectory(atPath: projectPath) {
            for file in files where file.hasSuffix(".jsonl") {
                let filePath = projectPath + "/" + file
                
                if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
                    let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
                    
                    for line in lines.prefix(50) {
                        if let data = line.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let message = json["message"] as? [String: Any],
                           let usage = message["usage"] as? [String: Any] {
                            
                            let model = message["model"] as? String ?? "unknown"
                            let inputTokens = usage["input_tokens"] as? Int ?? 0
                            let outputTokens = usage["output_tokens"] as? Int ?? 0
                            let timestamp = json["timestamp"] as? String ?? ""
                            
                            if inputTokens > 0 || outputTokens > 0 {
                                // Calculate cost using ModelPricing
                                var cost = 0.0
                                if model.lowercased().contains("opus") {
                                    cost = (Double(inputTokens) / 1_000_000) * 15.0 +
                                           (Double(outputTokens) / 1_000_000) * 75.0
                                } else if model.lowercased().contains("sonnet") {
                                    cost = (Double(inputTokens) / 1_000_000) * 3.0 +
                                           (Double(outputTokens) / 1_000_000) * 15.0
                                }
                                
                                let entry = UsageEntry(
                                    project: decodedPath,
                                    timestamp: timestamp,
                                    model: model,
                                    inputTokens: inputTokens,
                                    outputTokens: outputTokens,
                                    cacheWriteTokens: 0,
                                    cacheReadTokens: 0,
                                    cost: cost,
                                    sessionId: nil
                                )
                                
                                allEntries.append(entry)
                            }
                        }
                    }
                }
            }
        }
    }
}

if allEntries.isEmpty {
    print("\n⚠️ No usage data found")
} else {
    // Group by date
    var dailyUsage: [String: (cost: Double, inputTokens: Int, outputTokens: Int, models: Set<String>)] = [:]
    
    for entry in allEntries {
        if let date = entry.date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateStr = formatter.string(from: date)
            
            var current = dailyUsage[dateStr] ?? (0, 0, 0, Set<String>())
            current.cost += entry.cost
            current.inputTokens += entry.inputTokens
            current.outputTokens += entry.outputTokens
            current.models.insert(entry.model)
            dailyUsage[dateStr] = current
        }
    }
    
    // Display table
    print("\n┌────────────┬────────────────────┬───────────┬───────────┬─────────────┐")
    print("│ Date       │ Models             │     Input │    Output │  Cost (USD) │")
    print("├────────────┼────────────────────┼───────────┼───────────┼─────────────┤")
    
    let sortedDays = dailyUsage.keys.sorted()
    var totalCost = 0.0
    var totalInput = 0
    var totalOutput = 0
    
    for day in sortedDays {
        if let usage = dailyUsage[day] {
            let modelStr = usage.models.first?.components(separatedBy: "-").prefix(2).joined(separator: "-") ?? ""
            
            print(String(format: "│ %-10s │ - %-16s │ %9d │ %9d │    $%7.2f │",
                        day,
                        modelStr,
                        usage.inputTokens,
                        usage.outputTokens,
                        usage.cost))
            
            totalCost += usage.cost
            totalInput += usage.inputTokens
            totalOutput += usage.outputTokens
        }
    }
    
    print("├────────────┼────────────────────┼───────────┼───────────┼─────────────┤")
    print(String(format: "│ %-10s │ %-18s │ %9d │ %9d │    $%7.2f │",
                "TOTAL",
                "",
                totalInput,
                totalOutput,
                totalCost))
    print("└────────────┴────────────────────┴───────────┴───────────┴─────────────┘")
    
    print("\n📊 Summary:")
    print("  • Total entries: \(allEntries.count)")
    print("  • Days with data: \(dailyUsage.count)")
    print("  • Total cost: $\(String(format: "%.2f", totalCost))")
}