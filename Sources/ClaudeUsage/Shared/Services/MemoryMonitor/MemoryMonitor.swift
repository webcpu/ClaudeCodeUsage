//
//  MemoryMonitor.swift
//  ClaudeCodeUsage
//
//  Memory monitoring and management for the menu bar app
//
//  Split into extensions for focused responsibilities:
//    - +Types: Memory types, constants, and pure functions
//    - +System: System memory infrastructure
//

import Foundation
import Observation
import os.log

private let logger = Logger(subsystem: "com.claudecodeusage", category: "MemoryMonitor")

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
