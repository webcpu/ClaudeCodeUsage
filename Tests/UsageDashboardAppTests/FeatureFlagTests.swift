//
//  FeatureFlagTests.swift
//  Tests for FeatureFlags that need serial execution
//

import XCTest
@testable import UsageDashboardApp

/// Separate test class for feature flag tests that need serial execution
/// These tests modify UserDefaults which is a shared resource
final class FeatureFlagTests: XCTestCase {
    
    /// Shared lock to ensure feature flag tests don't run simultaneously
    private static let testLock = NSLock()
    
    override func setUp() {
        super.setUp()
        // Acquire lock to ensure exclusive access to UserDefaults
        Self.testLock.lock()
        // Reset feature flags to ensure clean state for each test
        FeatureFlags.reset()
    }
    
    override func tearDown() {
        // Clean up after each test
        FeatureFlags.reset()
        // Release lock
        Self.testLock.unlock()
        super.tearDown()
    }
    
    func testFeatureFlagPersistence() {
        // Test setting to true
        FeatureFlags.useActorBasedLiveMonitor = true
        XCTAssertTrue(FeatureFlags.useActorBasedLiveMonitor)
        
        // Test setting to false
        FeatureFlags.useActorBasedLiveMonitor = false
        XCTAssertFalse(FeatureFlags.useActorBasedLiveMonitor)
        
        // Test reset functionality
        FeatureFlags.reset()
        XCTAssertFalse(FeatureFlags.useActorBasedLiveMonitor)
    }
    
    func testFeatureFlagPercentageRollout() {
        // Test 0% rollout
        FeatureFlags.enableActorBasedLiveMonitor(percentage: 0)
        XCTAssertFalse(FeatureFlags.useActorBasedLiveMonitor)
        
        // Test 100% rollout
        FeatureFlags.enableActorBasedLiveMonitor(percentage: 100)
        XCTAssertTrue(FeatureFlags.useActorBasedLiveMonitor)
    }
    
    #if DEBUG
    func testDebugFeatureFlags() {
        // Test enabling all features
        FeatureFlags.enableAllExperimentalFeatures()
        XCTAssertTrue(FeatureFlags.useActorBasedLiveMonitor)
        
        // Test disabling all features
        FeatureFlags.disableAllExperimentalFeatures()
        XCTAssertFalse(FeatureFlags.useActorBasedLiveMonitor)
    }
    #endif
    
    // Note: These tests modify UserDefaults which is a shared resource.
    // They should not be run in parallel with other tests that use FeatureFlags.
    // Consider running these tests separately or using mock UserDefaults.
}