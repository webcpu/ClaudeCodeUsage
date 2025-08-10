//
//  DeduplicationConcurrencyTest.swift
//  Test to ensure deduplication doesn't interfere with concurrent repository calls
//

import XCTest
@testable import ClaudeCodeUsage
@testable import UsageDashboardApp

final class DeduplicationConcurrencyTest: XCTestCase {
    
    @MainActor
    func testConcurrentRepositoryCallsDontInterfere() async throws {
        // This test ensures that concurrent calls to getUsageStats and getUsageEntries
        // don't interfere with each other through shared deduplication state
        
        let client = ClaudeUsageClient(dataSource: .localFiles(basePath: NSHomeDirectory() + "/.claude"))
        
        // Run multiple concurrent operations
        async let stats1 = client.getUsageStats()
        async let entries1 = client.getUsageDetails()
        async let stats2 = client.getUsageStats()
        async let entries2 = client.getUsageDetails()
        
        // Await all results
        let (statsResult1, entriesResult1, statsResult2, entriesResult2) = try await (stats1, entries1, stats2, entries2)
        
        // All operations should return the same data
        XCTAssertEqual(statsResult1.totalCost, statsResult2.totalCost, accuracy: 0.01, 
                      "Stats should be consistent across concurrent calls")
        XCTAssertEqual(entriesResult1.count, entriesResult2.count, 
                      "Entry counts should be consistent across concurrent calls")
        
        // Verify entries aren't being incorrectly deduplicated
        XCTAssertGreaterThan(entriesResult1.count, 0, "Should have entries")
        
        // Test with UsageViewModel which uses concurrent loading
        let viewModel = UsageViewModel()
        await viewModel.loadData()
        
        // Filter entries for today to match what ViewModel does
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todaysEntriesFromDirect = entriesResult1.filter { entry in
            guard let date = entry.date else { return false }
            return calendar.isDate(date, inSameDayAs: today)
        }
        
        // ViewModel should see the same number of today's entries
        XCTAssertEqual(viewModel.todayEntries.count, todaysEntriesFromDirect.count,
                      "ViewModel should see correct number of today's entries")
    }
    
    func testDeduplicationIsLocalToEachOperation() async throws {
        // This test verifies that each repository operation uses its own deduplication instance
        
        let repository = UsageRepository(basePath: NSHomeDirectory() + "/.claude")
        
        // First call - should process all entries
        let entries1 = try await repository.getUsageEntries()
        let count1 = entries1.count
        
        // Second call immediately after - should still process all entries
        // (not be affected by deduplication from first call)
        let entries2 = try await repository.getUsageEntries()
        let count2 = entries2.count
        
        XCTAssertEqual(count1, count2, 
                      "Sequential calls should return the same number of entries")
        XCTAssertGreaterThan(count1, 0, "Should have entries to process")
        
        // Verify the entries are actually the same by comparing timestamps
        let timestamps1 = Set(entries1.map { $0.timestamp })
        let timestamps2 = Set(entries2.map { $0.timestamp })
        
        XCTAssertEqual(timestamps1, timestamps2, "Both calls should return the same entries")
    }
}