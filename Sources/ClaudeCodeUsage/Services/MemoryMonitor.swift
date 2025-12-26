//
//  MemoryMonitor.swift
//  UsageDashboardApp
//
//  Memory monitoring and management for the menu bar app
//

import Foundation
import Observation
import os.log

private let logger = Logger(subsystem: "com.claudecodeusage.app", category: "MemoryMonitor")

// MARK: - Memory Information

/// Memory usage statistics
public struct MemoryStats: Sendable {
    public let usedMemory: Int64        // Bytes
    public let freeMemory: Int64        // Bytes
    public let totalMemory: Int64       // Bytes
    public let footprint: Int64         // App's memory footprint
    public let peakFootprint: Int64     // Peak memory usage
    public let timestamp: Date
    
    public var usedMemoryMB: Double {
        Double(usedMemory) / 1_048_576
    }
    
    public var footprintMB: Double {
        Double(footprint) / 1_048_576
    }
    
    public var memoryPressure: MemoryPressureLevel {
        let usageRatio = Double(footprint) / Double(totalMemory)
        switch usageRatio {
        case ..<0.01: return .nominal
        case ..<0.05: return .warning
        case ..<0.10: return .critical
        default: return .terminal
        }
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
    public var warningThresholdMB: Double = 100.0
    public var criticalThresholdMB: Double = 200.0
    public var historyLimit: Int = 100
    public var updateInterval: TimeInterval = 30.0
    
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
    public func getMemoryTrend() -> String {
        guard memoryHistory.count >= 2 else { return "stable" }
        
        let recent = memoryHistory.suffix(5)
        let firstValue = recent.first?.footprint ?? 0
        let lastValue = recent.last?.footprint ?? 0
        
        let change = lastValue - firstValue
        let changePercent = Double(change) / Double(firstValue) * 100
        
        if changePercent > 10 {
            return "increasing"
        } else if changePercent < -10 {
            return "decreasing"
        } else {
            return "stable"
        }
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
        
        let footprint = result == KERN_SUCCESS ? Int64(info.resident_size) : 0
        
        // Get system memory info
        let pageSize = vm_kernel_page_size
        var vmStats = vm_statistics64()
        var vmStatsSize = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<natural_t>.size)
        
        let hostPort = mach_host_self()
        let vmResult = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmStatsSize)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &vmStatsSize)
            }
        }
        
        let totalMemory: Int64
        let freeMemory: Int64
        
        if vmResult == KERN_SUCCESS {
            totalMemory = Int64(ProcessInfo.processInfo.physicalMemory)
            freeMemory = Int64(vmStats.free_count) * Int64(pageSize)
        } else {
            totalMemory = Int64(ProcessInfo.processInfo.physicalMemory)
            freeMemory = totalMemory / 2 // Rough estimate
        }
        
        let usedMemory = totalMemory - freeMemory
        
        return MemoryStats(
            usedMemory: usedMemory,
            freeMemory: freeMemory,
            totalMemory: totalMemory,
            footprint: footprint,
            peakFootprint: footprint, // Would need rusage for actual peak
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

// MARK: - Memory Monitor View Component

import SwiftUI

/// SwiftUI view for displaying memory stats
public struct MemoryMonitorView: View {
    @State private var monitor = MemoryMonitor()
    @State private var showDetails = false
    
    public init() {}
    
    public var body: some View {
        Group {
            if let stats = monitor.currentStats {
                HStack {
                    Image(systemName: memoryIcon(for: stats.memoryPressure))
                        .foregroundColor(memoryColor(for: stats.memoryPressure))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Memory: \(stats.footprintMB, specifier: "%.1f") MB")
                            .font(.caption)
                        
                        if monitor.isMemoryPressureHigh() {
                            Text("High Usage")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: { showDetails.toggle() }) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            } else {
                Text("Memory: --")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
        }
        .onAppear {
            monitor.startMonitoring()
        }
        .onDisappear {
            monitor.stopMonitoring()
        }
        .sheet(isPresented: $showDetails) {
            MemoryDetailsView(monitor: monitor)
        }
    }
    
    private func memoryIcon(for level: MemoryPressureLevel) -> String {
        switch level {
        case .nominal: return "memorychip"
        case .warning: return "exclamationmark.triangle"
        case .critical: return "exclamationmark.triangle.fill"
        case .terminal: return "xmark.circle.fill"
        }
    }
    
    private func memoryColor(for level: MemoryPressureLevel) -> Color {
        switch level {
        case .nominal: return .green
        case .warning: return .yellow
        case .critical: return .orange
        case .terminal: return .red
        }
    }
}

/// Detailed memory statistics view
struct MemoryDetailsView: View {
    let monitor: MemoryMonitor
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Memory Statistics")
                    .font(.headline)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
            }
            
            if let stats = monitor.currentStats {
                VStack(alignment: .leading, spacing: 8) {
                    StatRow(label: "App Memory", value: "\(stats.footprintMB) MB")
                    StatRow(label: "System Used", value: "\(stats.usedMemoryMB) MB")
                    StatRow(label: "Free Memory", value: "\(Double(stats.freeMemory) / 1_048_576) MB")
                    StatRow(label: "Pressure Level", value: stats.memoryPressure.rawValue)
                    StatRow(label: "Trend", value: monitor.getMemoryTrend())
                }
                
                Divider()
                
                // Memory history chart could go here
                Text("History (\(monitor.memoryHistory.count) samples)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 300, height: 250)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.caption)
    }
}