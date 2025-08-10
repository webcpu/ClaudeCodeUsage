//
//  ErrorScenarioTests.swift
//  Comprehensive error scenario testing following TDD principles
//

import Testing
import Foundation
@testable import ClaudeCodeUsage
@testable import UsageDashboardApp

// MARK: - File System Error Scenarios

@Suite("When file system operations fail")
final class FileSystemErrorTests {
    
    @Test("Should show user-friendly message when Claude directory doesn't exist")
    @MainActor
    func handlesMissingDirectory() async {
        // Given
        let mockFileSystem = MockFileSystem()
        mockFileSystem.shouldThrowError = true
        mockFileSystem.errorToThrow = FileSystemError.directoryNotFound
        
        let repository = UsageRepository(fileSystem: mockFileSystem)
        let viewModel = UsageViewModel(repository: repository)
        
        // When
        await viewModel.loadData()
        
        // Then
        #expect(viewModel.error != nil)
        #expect(viewModel.errorMessage == "Claude data directory not found. Please ensure Claude Desktop is installed.")
        #expect(viewModel.stats == nil)
    }
    
    @Test("Should retry with exponential backoff on temporary file lock")
    @MainActor
    func retriesOnFileLock() async {
        // Given
        let mockFileSystem = MockFileSystem()
        mockFileSystem.failureCount = 2 // Fail twice, then succeed
        mockFileSystem.errorToThrow = FileSystemError.fileLocked
        
        let repository = UsageRepository(
            fileSystem: mockFileSystem,
            retryPolicy: ExponentialBackoff(maxRetries: 3)
        )
        
        // When
        let result = await repository.loadEntries()
        
        // Then
        #expect(result != nil)
        #expect(mockFileSystem.attemptCount == 3) // 2 failures + 1 success
    }
    
    @Test("Should handle permission denied gracefully")
    func handlesPermissionDenied() async {
        // Given
        let mockFileSystem = MockFileSystem()
        mockFileSystem.errorToThrow = FileSystemError.permissionDenied
        
        // When
        let repository = UsageRepository(fileSystem: mockFileSystem)
        
        // Then
        await #expect(throws: FileSystemError.permissionDenied) {
            try await repository.loadUsageEntries()
        }
    }
}

// MARK: - Data Corruption Scenarios

@Suite("When data is corrupted or invalid")
final class DataCorruptionTests {
    
    @Test("Should skip corrupted JSON files and continue")
    func skipsCorruptedFiles() async {
        // Given
        let mockParser = MockUsageDataParser()
        mockParser.corruptFiles = ["project1.json"]
        mockParser.validFiles = ["project2.json": validUsageData()]
        
        let repository = UsageRepository(parser: mockParser)
        
        // When
        let entries = await repository.loadEntries()
        
        // Then
        #expect(entries.count == 1) // Only valid file loaded
        #expect(mockParser.skippedFiles.contains("project1.json"))
    }
    
    @Test("Should handle malformed dates gracefully")
    func handlesMalformedDates() {
        // Given
        let invalidEntry = """
        {
            "timestamp": "not-a-date",
            "cost": 10.0,
            "tokens": 100
        }
        """
        
        // When
        let parser = UsageDataParser()
        let result = parser.parse(invalidEntry)
        
        // Then
        #expect(result == nil) // Should return nil, not crash
    }
    
    @Test("Should sanitize extreme values")
    func sanitizesExtremeValues() {
        // Given
        let entry = UsageEntry(
            timestamp: Date(),
            cost: Double.infinity,
            tokens: Int.max
        )
        
        // When
        let sanitized = entry.sanitized()
        
        // Then
        #expect(sanitized.cost == 999_999.99) // Capped at reasonable max
        #expect(sanitized.tokens == 1_000_000_000) // Capped at 1 billion
    }
}

// MARK: - Network Error Scenarios

@Suite("When network operations fail")
final class NetworkErrorTests {
    
    @Test("Should show offline mode when network unavailable")
    @MainActor
    func handlesOfflineMode() async {
        // Given
        let mockNetwork = MockNetworkService()
        mockNetwork.isOnline = false
        
        let viewModel = UsageViewModel(network: mockNetwork)
        
        // When
        await viewModel.syncWithCloud()
        
        // Then
        #expect(viewModel.isOfflineMode == true)
        #expect(viewModel.lastSyncDate == nil)
        #expect(viewModel.offlineMessage == "Working offline. Changes will sync when connected.")
    }
    
    @Test("Should queue operations when offline")
    func queuesOfflineOperations() async {
        // Given
        let mockNetwork = MockNetworkService()
        mockNetwork.isOnline = false
        
        let syncService = SyncService(network: mockNetwork)
        
        // When
        await syncService.uploadUsage(entry: testEntry())
        await syncService.uploadUsage(entry: testEntry())
        
        // Then
        #expect(syncService.pendingOperations.count == 2)
        
        // When network comes back
        mockNetwork.isOnline = true
        await syncService.processPendingOperations()
        
        // Then
        #expect(syncService.pendingOperations.isEmpty)
        #expect(mockNetwork.uploadCount == 2)
    }
}

// MARK: - Memory Pressure Scenarios

@Suite("When system is under memory pressure")
final class MemoryPressureTests {
    
    @Test("Should clear caches on memory warning")
    @MainActor
    func clearsGachesOnMemoryWarning() {
        // Given
        let cacheManager = CacheManager.shared
        cacheManager.cache(data: largeDataset(), for: "test")
        #expect(cacheManager.memoryUsage > 0)
        
        // When
        NotificationCenter.default.post(
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Then
        #expect(cacheManager.memoryUsage == 0)
        #expect(cacheManager.isEmpty)
    }
    
    @Test("Should use disk cache when memory limited")
    func usesDiskCacheWhenMemoryLimited() async {
        // Given
        let cache = AdaptiveCache(memoryLimit: 1024) // 1KB limit
        let largeData = Data(repeating: 0, count: 10_000) // 10KB
        
        // When
        await cache.store(largeData, key: "large")
        
        // Then
        #expect(cache.isInMemory("large") == false)
        #expect(cache.isOnDisk("large") == true)
    }
}

// MARK: - Concurrency Error Scenarios

@Suite("When concurrent operations conflict")
final class ConcurrencyErrorTests {
    
    @Test("Should prevent data races in shared state")
    @MainActor
    func preventsDataRaces() async {
        // Given
        let viewModel = UsageViewModel()
        let iterations = 1000
        
        // When - Concurrent updates
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    await viewModel.incrementCounter()
                }
            }
        }
        
        // Then
        #expect(viewModel.counter == iterations) // No lost updates
    }
    
    @Test("Should cancel previous operation when new one starts")
    @MainActor
    func cancelsPreviousOperation() async {
        // Given
        let viewModel = UsageViewModel()
        let slowOperation = MockSlowOperation(duration: 5.0)
        
        // When
        let task1 = Task {
            await viewModel.performOperation(slowOperation)
        }
        
        // Start second operation immediately
        let task2 = Task {
            await viewModel.performOperation(MockQuickOperation())
        }
        
        // Then
        await task2.value
        #expect(task1.isCancelled)
        #expect(viewModel.lastOperation == "quick")
    }
}

// MARK: - User Input Error Scenarios

@Suite("When users provide invalid input")
final class UserInputErrorTests {
    
    @Test("Should validate date range selections")
    func validatesDateRange() {
        // Given
        let viewModel = DateRangeViewModel()
        
        // When - End date before start date
        viewModel.startDate = Date()
        viewModel.endDate = Date().addingTimeInterval(-86400) // Yesterday
        
        // Then
        #expect(viewModel.isValidRange == false)
        #expect(viewModel.validationError == "End date must be after start date")
    }
    
    @Test("Should handle rapid user interactions")
    @MainActor
    func handlesRapidInteractions() async {
        // Given
        let viewModel = HeatmapViewModel()
        let locations = (0..<100).map { CGPoint(x: $0, y: $0) }
        
        // When - Rapid hover events
        for location in locations {
            viewModel.handleHover(at: location, in: .zero)
        }
        
        // Then - Should only process last event
        #expect(viewModel.hoverEventCount <= 10) // Debounced
        #expect(viewModel.lastHoverLocation == locations.last)
    }
    
    @Test("Should prevent invalid configuration")
    func preventsInvalidConfiguration() {
        // Given
        var config = AppConfiguration()
        
        // When
        config.refreshInterval = -1 // Invalid negative value
        config.maxRetries = 1000 // Unreasonably high
        
        // Then
        #expect(config.validatedRefreshInterval == 30) // Default
        #expect(config.validatedMaxRetries == 3) // Capped
    }
}

// MARK: - Edge Case Scenarios

@Suite("Edge cases that emerge from TDD")
final class EdgeCaseTests {
    
    @Test("Should handle empty response gracefully")
    func handlesEmptyResponse() async {
        // Given
        let service = DataService()
        
        // When
        let result = await service.processData([])
        
        // Then
        #expect(result.isEmpty)
        #expect(result.summary == "No data available")
    }
    
    @Test("Should handle single data point")
    func handlesSingleDataPoint() {
        // Given
        let calculator = StatisticsCalculator()
        let singlePoint = [DataPoint(value: 42)]
        
        // When
        let stats = calculator.calculate(singlePoint)
        
        // Then
        #expect(stats.mean == 42)
        #expect(stats.median == 42)
        #expect(stats.standardDeviation == 0)
    }
    
    @Test("Should handle boundary values")
    func handlesBoundaryValues() {
        // Given
        let paginator = Paginator(pageSize: 10)
        
        // When/Then - Empty data
        #expect(paginator.pageCount(for: 0) == 0)
        
        // When/Then - Exact page boundary
        #expect(paginator.pageCount(for: 10) == 1)
        #expect(paginator.pageCount(for: 20) == 2)
        
        // When/Then - One over boundary
        #expect(paginator.pageCount(for: 11) == 2)
        #expect(paginator.pageCount(for: 21) == 3)
    }
}

// MARK: - Recovery Scenarios

@Suite("System should recover from errors")
final class ErrorRecoveryTests {
    
    @Test("Should auto-retry transient failures")
    func autoRetriesTransientFailures() async {
        // Given
        let service = ResilientService()
        service.failureMode = .transient(times: 2)
        
        // When
        let result = await service.fetchData()
        
        // Then
        #expect(result != nil)
        #expect(service.attemptCount == 3) // 2 failures + 1 success
    }
    
    @Test("Should fallback to cache on persistent failure")
    func fallbacksToCache() async {
        // Given
        let service = DataService()
        service.cache.store(cachedData, key: "fallback")
        service.networkAvailable = false
        
        // When
        let result = await service.getData()
        
        // Then
        #expect(result == cachedData)
        #expect(service.usedFallback == true)
    }
    
    @Test("Should gracefully degrade features")
    @MainActor
    func degradesGracefully() async {
        // Given
        let viewModel = AdvancedFeaturesViewModel()
        viewModel.systemCapabilities.lowPowerMode = true
        
        // When
        await viewModel.initialize()
        
        // Then
        #expect(viewModel.animationsEnabled == false)
        #expect(viewModel.refreshRate == .reduced)
        #expect(viewModel.backgroundProcessing == false)
    }
}

// MARK: - Mock Infrastructure

final class MockFileSystem: FileSystemProtocol {
    var shouldThrowError = false
    var errorToThrow: Error = FileSystemError.unknown
    var failureCount = 0
    var attemptCount = 0
    
    func readFile(at path: String) throws -> Data {
        attemptCount += 1
        
        if shouldThrowError && attemptCount <= failureCount {
            throw errorToThrow
        }
        
        return Data()
    }
}

enum FileSystemError: Error {
    case directoryNotFound
    case fileLocked
    case permissionDenied
    case unknown
}