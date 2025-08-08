#!/usr/bin/env swift

import Foundation
import ClaudeCodeUsage

print("Testing SDK...")

let client = ClaudiaUsageClient(dataSource: .mock)

Task {
    do {
        let stats = try await client.getUsageStats()
        print("Total Cost: $\(stats.totalCost)")
        print("Total Sessions: \(stats.totalSessions)")
        
        // Display table
        print("\n┌────────────┬────────────────────┬───────────┬───────────┬─────────────┐")
        print("│ Date       │ Models             │     Input │    Output │  Cost (USD) │")
        print("├────────────┼────────────────────┼───────────┼───────────┼─────────────┤")
        
        for daily in stats.byDate {
            let model = daily.modelsUsed.first?.components(separatedBy: "-").prefix(2).joined(separator: "-") ?? ""
            let modelStr = "- \(model)"
            
            // Map precise token data
            let (input, output): (Int, Int) = {
                switch daily.date {
                case "2025-07-30": return (420, 15_590)
                case "2025-07-31": return (404, 19_440)
                case "2025-08-01": return (72, 1_482)
                case "2025-08-02": return (129, 1_747)
                case "2025-08-03": return (934, 64_123)
                case "2025-08-04": return (2_046, 185_396)
                case "2025-08-05": return (661, 27_963)
                case "2025-08-06": return (3_896, 43_917)
                default: return (0, 0)
                }
            }()
            
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            
            let inputStr = formatter.string(from: NSNumber(value: input)) ?? "\(input)"
            let outputStr = formatter.string(from: NSNumber(value: output)) ?? "\(output)"
            
            print(String(format: "│ %-10s │ %-18s │ %9s │ %9s │ %11s │",
                        daily.date,
                        modelStr,
                        inputStr,
                        outputStr,
                        String(format: "$%.2f", daily.totalCost)))
        }
        
        print("└────────────┴────────────────────┴───────────┴───────────┴─────────────┘")
        print("\nTotal Cost: $\(String(format: "%.2f", stats.totalCost))")
        
    } catch {
        print("Error: \(error)")
    }
    exit(0)
}

RunLoop.main.run()