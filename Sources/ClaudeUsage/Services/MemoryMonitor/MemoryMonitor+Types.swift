//
//  MemoryMonitor+Types.swift
//
//  Memory types, constants, and pure functions.
//

import Foundation

// MARK: - Constants

enum MemoryConstants {
    static let bytesPerMegabyte: Double = 1_048_576

    enum PressureThreshold {
        static let warning: Double = 0.01
        static let critical: Double = 0.05
        static let terminal: Double = 0.10
    }

    enum TrendThreshold {
        static let changePercent: Double = 10.0
        static let sampleCount = 5
    }

    enum Defaults {
        static let warningThresholdMB: Double = 100.0
        static let criticalThresholdMB: Double = 200.0
        static let historyLimit = 100
        static let updateInterval: TimeInterval = 30.0
    }
}

// MARK: - Pure Functions

func bytesToMegabytes(_ bytes: Int64) -> Double {
    Double(bytes) / MemoryConstants.bytesPerMegabyte
}

func calculatePressureLevel(footprint: Int64, totalMemory: Int64) -> MemoryPressureLevel {
    let usageRatio = Double(footprint) / Double(totalMemory)
    switch usageRatio {
    case ..<MemoryConstants.PressureThreshold.warning: return .nominal
    case ..<MemoryConstants.PressureThreshold.critical: return .warning
    case ..<MemoryConstants.PressureThreshold.terminal: return .critical
    default: return .terminal
    }
}

func calculateTrend(from history: [MemoryStats]) -> MemoryTrend {
    guard history.count >= 2 else { return .stable }

    let recent = history.suffix(MemoryConstants.TrendThreshold.sampleCount)
    guard let first = recent.first, let last = recent.last, first.footprint > 0 else {
        return .stable
    }

    let changePercent = Double(last.footprint - first.footprint) / Double(first.footprint) * 100

    switch changePercent {
    case MemoryConstants.TrendThreshold.changePercent...: return .increasing
    case ..<(-MemoryConstants.TrendThreshold.changePercent): return .decreasing
    default: return .stable
    }
}

// MARK: - Memory Trend

public enum MemoryTrend: String, Sendable {
    case increasing
    case decreasing
    case stable
}

// MARK: - Memory Statistics

/// Memory usage statistics
public struct MemoryStats: Sendable {
    public let usedMemory: Int64
    public let freeMemory: Int64
    public let totalMemory: Int64
    public let footprint: Int64
    public let peakFootprint: Int64
    public let timestamp: Date

    public var usedMemoryMB: Double {
        bytesToMegabytes(usedMemory)
    }

    public var freeMemoryMB: Double {
        bytesToMegabytes(freeMemory)
    }

    public var footprintMB: Double {
        bytesToMegabytes(footprint)
    }

    public var memoryPressure: MemoryPressureLevel {
        calculatePressureLevel(footprint: footprint, totalMemory: totalMemory)
    }
}

// MARK: - Memory Pressure Level

/// Memory pressure levels
public enum MemoryPressureLevel: String, CaseIterable, Sendable {
    case nominal = "Nominal"
    case warning = "Warning"
    case critical = "Critical"
    case terminal = "Terminal"

    public var color: String {
        switch self {
        case .nominal: return "green"
        case .warning: return "yellow"
        case .critical: return "orange"
        case .terminal: return "red"
        }
    }

    public var systemImage: String {
        switch self {
        case .nominal: return "memorychip"
        case .warning: return "exclamationmark.triangle"
        case .critical: return "exclamationmark.triangle.fill"
        case .terminal: return "xmark.circle.fill"
        }
    }
}
