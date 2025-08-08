#!/usr/bin/env swift

import Foundation

// Expected values from the table
let expected = [
    "2025-07-30": (input: 420, output: 15590, cost: 4.00),
    "2025-07-31": (input: 404, output: 19440, cost: 10.04),
    "2025-08-01": (input: 72, output: 1482, cost: 0.40),
    "2025-08-02": (input: 129, output: 1747, cost: 1.07),
    "2025-08-03": (input: 934, output: 64123, cost: 12.07),
    "2025-08-04": (input: 2046, output: 185396, cost: 40.06),
    "2025-08-05": (input: 661, output: 27963, cost: 6.12),
    "2025-08-06": (input: 3896, output: 43917, cost: 108.85),
    "2025-08-07": (input: 3400, output: 30784, cost: 63.21)
]

// Actual values from SDK
let actual = [
    "2025-07-30": (input: 577, output: 24350),
    "2025-07-31": (input: 620, output: 81844),
    "2025-08-01": (input: 178, output: 6752),
    "2025-08-02": (input: 183, output: 9217),
    "2025-08-03": (input: 1465, output: 107499),
    "2025-08-04": (input: 2994, output: 314364),
    "2025-08-05": (input: 973, output: 49213),
    "2025-08-06": (input: 6830, output: 216705),
    "2025-08-07": (input: 9996, output: 144842)
]

print("🔍 Analyzing Unit Differences")
print(String(repeating: "=", count: 72))

print("\n📊 Token Count Comparison:")
print("┌────────────┬─────────────────────┬─────────────────────┬──────────┐")
print("│ Date       │ Expected (Table)    │ Actual (SDK)        │ Ratio    │")
print("├────────────┼─────────────────────┼─────────────────────┼──────────┤")

for date in expected.keys.sorted() {
    let exp = expected[date]!
    let act = actual[date]!
    
    let inputRatio = Double(act.input) / Double(exp.input)
    let outputRatio = Double(act.output) / Double(exp.output)
    
    print(String(format: "│ %s │ I: %6d O: %7d │ I: %6d O: %7d │ I: %.2fx  │",
                date,
                exp.input,
                exp.output,
                act.input,
                act.output,
                inputRatio))
    print(String(format: "│            │                     │                     │ O: %.2fx  │",
                outputRatio))
}

print("└────────────┴─────────────────────┴─────────────────────┴──────────┘")

print("\n💡 Analysis:")

// Check if there's a consistent multiplier
var inputRatios: [Double] = []
var outputRatios: [Double] = []

for date in expected.keys {
    let exp = expected[date]!
    let act = actual[date]!
    
    inputRatios.append(Double(act.input) / Double(exp.input))
    outputRatios.append(Double(act.output) / Double(exp.output))
}

let avgInputRatio = inputRatios.reduce(0, +) / Double(inputRatios.count)
let avgOutputRatio = outputRatios.reduce(0, +) / Double(outputRatios.count)

print("   Average input ratio (actual/expected): \(String(format: "%.2f", avgInputRatio))")
print("   Average output ratio (actual/expected): \(String(format: "%.2f", avgOutputRatio))")

// Check if values might be in thousands
print("\n🔢 If table values are in thousands:")
for date in ["2025-07-30", "2025-08-06"] {
    let exp = expected[date]!
    print("\n   \(date):")
    print("     Expected: \(exp.input)K input, \(exp.output)K output")
    print("     As tokens: \(exp.input * 1000) input, \(exp.output * 1000) output")
    
    // Calculate cost at those levels
    let inputCostSonnet = Double(exp.input * 1000) * 3.0 / 1_000_000
    let outputCostSonnet = Double(exp.output * 1000) * 15.0 / 1_000_000
    let totalCostSonnet = inputCostSonnet + outputCostSonnet
    
    print("     Cost (Sonnet): $\(String(format: "%.2f", totalCostSonnet))")
    print("     Expected cost: $\(String(format: "%.2f", exp.cost))")
    
    if date == "2025-08-06" {
        // This day has Opus too
        let inputCostOpus = Double(exp.input * 1000) * 15.0 / 1_000_000
        let outputCostOpus = Double(exp.output * 1000) * 75.0 / 1_000_000
        let totalCostOpus = inputCostOpus + outputCostOpus
        print("     Cost (Opus): $\(String(format: "%.2f", totalCostOpus))")
    }
}