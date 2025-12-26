//
//  MemoryMonitor.swift
//  ClaudeCodeUsage
//
//  Memory monitoring and management for the menu bar app
//

import Foundation
import Observation
import os.log

private let logger = Logger(subsystem: "com.claudecodeusage.app", category: "MemoryMonitor")

// MARK: - Constants

private enum MemoryConstants {
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

private func bytesToMegabytes(_ bytes: Int64) -> Double {
    Double(bytes) / MemoryConstants.bytesPerMegabyte
}

private func calculatePressureLevel(footprint: Int64, totalMemory: Int64) -> MemoryPressureLevel {
    let usageRatio = Double(footprint) / Double(totalMemory)
    switch usageRatio {
    case ..<MemoryConstants.PressureThreshold.warning: return .nominal
    case ..<MemoryConstants.PressureThreshold.critical: return .warning
    case ..<MemoryConstants.PressureThreshold.terminal: return .critical
    default: return .terminal
    }
}

private func calculateTrend(from history: [MemoryStats]) -> MemoryTrend {
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

// MARK: - Memory Information

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

// MARK: - Memory Monitor

/// Monitors memory usage and provides alerts
@Observable
@MainActor
public final class MemoryMonitor {
    
    // MARK: - Properties
    
    public private(set) var currentStats: MemoryStats?
    public private(set) var isMonitoring = false
    public var memoryHistory: [MemoryStats] = [] // Made public for testing
    public private(set) var lastWarning: Date?
    
    // Configuration
    public var warningThresholdMB: Double = MemoryConstants.Defaults.warningThresholdMB
    public var criticalThresholdMB: Double = MemoryConstants.Defaults.criticalThresholdMB
    public var historyLimit: Int = MemoryConstants.Defaults.historyLimit
    public var updateInterval: TimeInterval = MemoryConstants.Defaults.updateInterval
    
    private var monitoringTask: Task<Void, Never>?
    private var pressureSource: DispatchSourceMemoryPressure?
    
    // MARK: - Initialization
    
    public init() {
        setupMemoryPressureHandler()
    }
    
    // Note: deinit not needed - Tasks are automatically cancelled
    
    // MARK: - Public Methods
    
    /// Start monitoring memory usage
    public func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        logger.info("Starting memory monitoring")
        
        monitoringTask = Task { [weak self] in
            guard let self else { return }
            
            while !Task.isCancelled {
                await self.updateMemoryStats()
                
                try? await Task.sleep(nanoseconds: UInt64(self.updateInterval * 1_000_000_000))
            }
        }
        
        // Initial update
        Task {
            await updateMemoryStats()
        }
    }
    
    /// Stop monitoring memory usage
    public func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
        logger.info("Stopped memory monitoring")
    }
    
    /// Force update memory statistics
    public func forceUpdate() async {
        await updateMemoryStats()
    }
    
    /// Clear memory history
    public func clearHistory() {
        memoryHistory.removeAll()
        logger.info("Cleared memory history")
    }
    
    /// Check if memory usage is high
    public func isMemoryPressureHigh() -> Bool {
        guard let stats = currentStats else { return false }
        return stats.footprintMB > warningThresholdMB
    }
    
    /// Get memory trend (increasing/decreasing)
    public func getMemoryTrend() -> MemoryTrend {
        calculateTrend(from: memoryHistory)
    }
    
    // MARK: - Private Methods
    
    private func updateMemoryStats() async {
        let stats = getMemoryStatistics()
        
        currentStats = stats
        
        // Add to history
        memoryHistory.append(stats)
        if memoryHistory.count > historyLimit {
            memoryHistory.removeFirst()
        }
        
        // Check thresholds
        checkMemoryThresholds(stats)
        
        logger.debug("Memory update: \(stats.footprintMB, format: .fixed(precision: 1))MB footprint")
    }
    
    private func getMemoryStatistics() -> MemoryStats {
        let footprint = SystemMemory.fetchTaskFootprint()
        let systemInfo = SystemMemory.fetchSystemInfo()

        return MemoryStats(
            usedMemory: systemInfo.total - systemInfo.free,
            freeMemory: systemInfo.free,
            totalMemory: systemInfo.total,
            footprint: footprint,
            peakFootprint: footprint,
            timestamp: Date()
        )
    }
    
    private func checkMemoryThresholds(_ stats: MemoryStats) {
        let footprintMB = stats.footprintMB
        
        if footprintMB > criticalThresholdMB {
            logger.error("Critical memory usage: \(footprintMB, format: .fixed(precision: 1))MB")
            handleMemoryWarning(.critical)
        } else if footprintMB > warningThresholdMB {
            logger.warning("High memory usage: \(footprintMB, format: .fixed(precision: 1))MB")
            handleMemoryWarning(.warning)
        }
    }
    
    private func handleMemoryWarning(_ level: MemoryPressureLevel) {
        lastWarning = Date()
        
        // Post notification for UI handling
        NotificationCenter.default.post(
            name: .memoryPressureChanged,
            object: nil,
            userInfo: ["level": level]
        )
        
        // Attempt to reduce memory if critical
        if level == .critical || level == .terminal {
            performMemoryCleanup()
        }
    }
    
    private func performMemoryCleanup() {
        logger.info("Performing memory cleanup")
        
        // Clear caches
        URLCache.shared.removeAllCachedResponses()
        
        // Post notification for app to clear caches
        NotificationCenter.default.post(name: .performMemoryCleanup, object: nil)
        
        // Suggest garbage collection (though ARC handles most)
        autoreleasepool {
            // Force autorelease pool drain
        }
    }
    
    private func setupMemoryPressureHandler() {
        pressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )
        
        pressureSource?.setEventHandler { [weak self] in
            guard let self else { return }
            
            let event = self.pressureSource?.data
            
            if event?.contains(.critical) == true {
                logger.critical("System memory pressure critical")
                Task { @MainActor in
                    self.handleMemoryWarning(.critical)
                }
            } else if event?.contains(.warning) == true {
                logger.warning("System memory pressure warning")
                Task { @MainActor in
                    self.handleMemoryWarning(.warning)
                }
            }
        }
        
        pressureSource?.resume()
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let memoryPressureChanged = Notification.Name("memoryPressureChanged")
    static let performMemoryCleanup = Notification.Name("performMemoryCleanup")
}

// MARK: - System Memory Infrastructure

private enum SystemMemory {
    struct Info {
        let total: Int64
        let free: Int64
    }

    static func fetchTaskFootprint() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }

    static func fetchSystemInfo() -> Info {
        let totalMemory = Int64(ProcessInfo.processInfo.physicalMemory)

        let pageSize = vm_kernel_page_size
        var vmStats = vm_statistics64()
        var vmStatsSize = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<natural_t>.size
        )

        let hostPort = mach_host_self()
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmStatsSize)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &vmStatsSize)
            }
        }

        let freeMemory = result == KERN_SUCCESS
            ? Int64(vmStats.free_count) * Int64(pageSize)
            : totalMemory / 2

        return Info(total: totalMemory, free: freeMemory)
    }
}

