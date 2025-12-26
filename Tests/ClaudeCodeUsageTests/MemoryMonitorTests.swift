//
//  MemoryMonitorTests.swift
//  UsageDashboardAppTests
//
//  Tests for memory monitoring functionality
//

import Foundation
import Testing
@testable import ClaudeCodeUsage

@Suite("Memory Monitor Tests")
struct MemoryMonitorTests {
    
    @Test("Memory monitor initializes correctly")
    @MainActor
    func testInitialization() async {
        // Arrange & Act
        let monitor = MemoryMonitor()
        
        // Assert
        #expect(monitor.isMonitoring == false)
        #expect(monitor.currentStats == nil)
        #expect(monitor.memoryHistory.isEmpty)
        #expect(monitor.warningThresholdMB == 100.0)
        #expect(monitor.criticalThresholdMB == 200.0)
    }
    
    @Test("Start monitoring updates stats")
    @MainActor
    func testStartMonitoring() async throws {
        // Arrange
        let monitor = MemoryMonitor()
        monitor.updateInterval = 0.1 // Fast updates for testing
        
        // Act
        monitor.startMonitoring()
        
        // Wait for initial update
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Assert
        #expect(monitor.isMonitoring == true)
        #expect(monitor.currentStats != nil)
        
        if let stats = monitor.currentStats {
            #expect(stats.footprint > 0)
            #expect(stats.totalMemory > 0)
            #expect(stats.timestamp.timeIntervalSinceNow < 1)
        }
        
        // Cleanup
        monitor.stopMonitoring()
    }
    
    @Test("Stop monitoring clears state")
    @MainActor
    func testStopMonitoring() async throws {
        // Arrange
        let monitor = MemoryMonitor()
        monitor.updateInterval = 0.1
        monitor.startMonitoring()
        
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Act
        monitor.stopMonitoring()
        
        // Assert
        #expect(monitor.isMonitoring == false)
    }
    
    @Test("Memory history respects limit")
    @MainActor
    func testMemoryHistoryLimit() async throws {
        // Arrange
        let monitor = MemoryMonitor()
        monitor.historyLimit = 3
        monitor.updateInterval = 0.05 // Very fast for testing
        
        // Act
        monitor.startMonitoring()
        
        // Wait for multiple updates
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Assert
        #expect(monitor.memoryHistory.count <= 3)
        
        // Cleanup
        monitor.stopMonitoring()
    }
    
    @Test("Memory pressure level calculation")
    @MainActor
    func testMemoryPressureLevels() {
        // Arrange
        let totalMemory: Int64 = 16_000_000_000 // 16GB
        
        // Test nominal pressure (< 1% of total)
        let nominalStats = MemoryStats(
            usedMemory: 8_000_000_000,
            freeMemory: 8_000_000_000,
            totalMemory: totalMemory,
            footprint: 100_000_000, // 100MB
            peakFootprint: 100_000_000,
            timestamp: Date()
        )
        #expect(nominalStats.memoryPressure == .nominal)
        
        // Test warning pressure (1-5% of total)
        let warningStats = MemoryStats(
            usedMemory: 8_000_000_000,
            freeMemory: 8_000_000_000,
            totalMemory: totalMemory,
            footprint: 500_000_000, // 500MB
            peakFootprint: 500_000_000,
            timestamp: Date()
        )
        #expect(warningStats.memoryPressure == .warning)
        
        // Test critical pressure (5-10% of total)
        let criticalStats = MemoryStats(
            usedMemory: 8_000_000_000,
            freeMemory: 8_000_000_000,
            totalMemory: totalMemory,
            footprint: 1_000_000_000, // 1GB
            peakFootprint: 1_000_000_000,
            timestamp: Date()
        )
        #expect(criticalStats.memoryPressure == .critical)
        
        // Test terminal pressure (> 10% of total)
        let terminalStats = MemoryStats(
            usedMemory: 8_000_000_000,
            freeMemory: 8_000_000_000,
            totalMemory: totalMemory,
            footprint: 2_000_000_000, // 2GB
            peakFootprint: 2_000_000_000,
            timestamp: Date()
        )
        #expect(terminalStats.memoryPressure == .terminal)
    }
    
    @Test("Memory trend detection")
    @MainActor
    func testMemoryTrendDetection() async throws {
        // Arrange
        let monitor = MemoryMonitor()
        
        // Manually add history entries with increasing footprint
        let baseFootprint: Int64 = 100_000_000 // 100MB
        
        for i in 0..<5 {
            let stats = MemoryStats(
                usedMemory: 8_000_000_000,
                freeMemory: 8_000_000_000,
                totalMemory: 16_000_000_000,
                footprint: baseFootprint + Int64(i * 20_000_000), // Increase by 20MB each
                peakFootprint: baseFootprint,
                timestamp: Date()
            )
            monitor.memoryHistory.append(stats)
        }
        
        // Act
        let trend = monitor.getMemoryTrend()
        
        // Assert
        #expect(trend == "increasing")
        
        // Test decreasing trend
        monitor.clearHistory()
        for i in 0..<5 {
            let stats = MemoryStats(
                usedMemory: 8_000_000_000,
                freeMemory: 8_000_000_000,
                totalMemory: 16_000_000_000,
                footprint: baseFootprint - Int64(i * 20_000_000), // Decrease by 20MB each
                peakFootprint: baseFootprint,
                timestamp: Date()
            )
            monitor.memoryHistory.append(stats)
        }
        
        let decreasingTrend = monitor.getMemoryTrend()
        #expect(decreasingTrend == "decreasing")
        
        // Test stable trend
        monitor.clearHistory()
        for _ in 0..<5 {
            let stats = MemoryStats(
                usedMemory: 8_000_000_000,
                freeMemory: 8_000_000_000,
                totalMemory: 16_000_000_000,
                footprint: baseFootprint, // Same footprint
                peakFootprint: baseFootprint,
                timestamp: Date()
            )
            monitor.memoryHistory.append(stats)
        }
        
        let stableTrend = monitor.getMemoryTrend()
        #expect(stableTrend == "stable")
    }
    
    @Test("Force update works")
    @MainActor
    func testForceUpdate() async throws {
        // Arrange
        let monitor = MemoryMonitor()
        
        // Act
        await monitor.forceUpdate()
        
        // Assert
        #expect(monitor.currentStats != nil)
        #expect(monitor.memoryHistory.count == 1)
    }
    
    @Test("Memory cleanup notification handling")
    @MainActor
    func testMemoryCleanupNotification() async throws {
        // Arrange
        let monitor = MemoryMonitor()
        var notificationReceived = false
        
        let observer = NotificationCenter.default.addObserver(
            forName: .performMemoryCleanup,
            object: nil,
            queue: .main
        ) { _ in
            notificationReceived = true
        }
        
        defer {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Act - Trigger critical memory pressure
        monitor.criticalThresholdMB = 0.001 // Very low threshold to trigger
        monitor.startMonitoring()
        await monitor.forceUpdate()
        
        // Wait for notification
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Assert
        #expect(notificationReceived == true)
        
        // Cleanup
        monitor.stopMonitoring()
    }
    
    @Test("Memory stats formatting")
    func testMemoryStatsFormatting() {
        // Arrange
        let stats = MemoryStats(
            usedMemory: 8_589_934_592, // 8GB
            freeMemory: 8_589_934_592, // 8GB
            totalMemory: 17_179_869_184, // 16GB
            footprint: 104_857_600, // 100MB
            peakFootprint: 209_715_200, // 200MB
            timestamp: Date()
        )
        
        // Act & Assert
        #expect(stats.usedMemoryMB == 8192.0)
        #expect(stats.footprintMB == 100.0)
    }
}