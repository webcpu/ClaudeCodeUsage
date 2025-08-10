//
//  FeatureFlagTests.swift
//  Tests for FeatureFlags that need serial execution
//  Migrated to Swift Testing Framework
//

import Testing
import Foundation
@testable import UsageDashboardApp

/// Separate test suite for feature flag tests that need serial execution
/// These tests modify UserDefaults which is a shared resource
@Suite("Feature Flag Tests", .serialized)
struct FeatureFlagTests {
    
    // Note: Using .serialized trait ensures tests run one at a time
    // This replaces the NSLock mechanism from XCTest
    
    init() {
        // Reset feature flags to ensure clean state for each test
        FeatureFlags.reset()
    }
    
    @Test("Feature flag persistence")
    func featureFlagPersistence() {
        // Test setting to true
        FeatureFlags.useActorBasedLiveMonitor = true
        #expect(FeatureFlags.useActorBasedLiveMonitor == true)
        
        // Test setting to false
        FeatureFlags.useActorBasedLiveMonitor = false
        #expect(FeatureFlags.useActorBasedLiveMonitor == false)
        
        // Test reset functionality
        FeatureFlags.reset()
        #expect(FeatureFlags.useActorBasedLiveMonitor == false)
        
        // Clean up after test
        FeatureFlags.reset()
    }
    
    @Test("Feature flag percentage rollout")
    func featureFlagPercentageRollout() {
        // Test 0% rollout
        FeatureFlags.enableActorBasedLiveMonitor(percentage: 0)
        #expect(FeatureFlags.useActorBasedLiveMonitor == false)
        
        // Test 100% rollout
        FeatureFlags.enableActorBasedLiveMonitor(percentage: 100)
        #expect(FeatureFlags.useActorBasedLiveMonitor == true)
        
        // Clean up after test
        FeatureFlags.reset()
    }
    
    #if DEBUG
    @Test("Debug feature flags")
    func debugFeatureFlags() {
        // Test enabling all features
        FeatureFlags.enableAllExperimentalFeatures()
        #expect(FeatureFlags.useActorBasedLiveMonitor == true)
        
        // Test disabling all features
        FeatureFlags.disableAllExperimentalFeatures()
        #expect(FeatureFlags.useActorBasedLiveMonitor == false)
        
        // Clean up after test
        FeatureFlags.reset()
    }
    #endif
    
    // Note: These tests modify UserDefaults which is a shared resource.
    // They should not be run in parallel with other tests that use FeatureFlags.
    // Consider running these tests separately or using mock UserDefaults.
}