//
//  UsageDataLoaderTests.swift
//  ClaudeUsageTests
//
//  Integration tests that mirror the actual app data loading flow
//

import Testing
import Foundation
@testable import ClaudeUsage
@testable import ClaudeUsageData
@testable import ClaudeUsageCore

@Suite("UsageDataLoader Integration")
struct UsageDataLoaderTests {
    private let basePath = NSHomeDirectory() + "/.claude"

    // MARK: - Phase 1: loadToday()

    @Test("Phase 1 loadToday measures actual app startup time")
    func phase1LoadToday() async throws {
        // Setup - mirrors UsageStore initialization
        let repository = UsageRepository(basePath: basePath)
        let sessionService = DefaultSessionMonitorService(configuration: .default)
        let loader = UsageDataLoader(repository: repository, sessionMonitorService: sessionService)

        // Phase 1 - This is the critical path for app startup
        let start = Date()
        let result = try await loader.loadToday()
        let duration = Date().timeIntervalSince(start)

        print("═══════════════════════════════════════════")
        print("Phase 1: loadToday() - App Startup Critical Path")
        print("═══════════════════════════════════════════")
        print("  Duration: \(String(format: "%.2f", duration))s")
        print("  Today entries: \(result.todayEntries.count)")
        print("  Today cost: $\(String(format: "%.2f", result.todayStats.totalCost))")
        print("  Session: \(result.session != nil ? "active" : "none")")
        print("  Token limit: \(result.autoTokenLimit.map { String($0) } ?? "none")")
        print("═══════════════════════════════════════════")

        // This is the current bottleneck - should be < 2s ideally
        #expect(result.todayEntries.count > 0)
    }

    @Test("Phase 2 loadHistory measures history load time")
    func phase2LoadHistory() async throws {
        let repository = UsageRepository(basePath: basePath)
        let sessionService = DefaultSessionMonitorService(configuration: .default)
        let loader = UsageDataLoader(repository: repository, sessionMonitorService: sessionService)

        // Warm up repository (simulates Phase 1 already completed)
        _ = try await loader.loadToday()

        // Phase 2
        let start = Date()
        let result = try await loader.loadHistory()
        let duration = Date().timeIntervalSince(start)

        print("═══════════════════════════════════════════")
        print("Phase 2: loadHistory() - Background Load")
        print("═══════════════════════════════════════════")
        print("  Duration: \(String(format: "%.2f", duration))s")
        print("  Total cost: $\(String(format: "%.2f", result.fullStats.totalCost))")
        print("  Days with usage: \(result.fullStats.byDate.count)")
        print("═══════════════════════════════════════════")

        #expect(result.fullStats.totalCost > 0)
    }

    // MARK: - Bottleneck Analysis

    @Test("identifies Phase 1 bottleneck between repository and session")
    func identifiesPhase1Bottleneck() async throws {
        let repository = UsageRepository(basePath: basePath)
        let sessionMonitor = SessionMonitor(basePath: basePath, sessionDurationHours: 5.0)

        // Measure repository (today entries only)
        let repoStart = Date()
        let entries = try await repository.getTodayEntries()
        let repoDuration = Date().timeIntervalSince(repoStart)

        // Measure session monitor (ALL files)
        let sessionStart = Date()
        let session = await sessionMonitor.getActiveSession()
        let sessionDuration = Date().timeIntervalSince(sessionStart)

        print("═══════════════════════════════════════════")
        print("Phase 1 Bottleneck Analysis")
        print("═══════════════════════════════════════════")
        print("  Repository (today): \(String(format: "%.2f", repoDuration))s")
        print("  SessionMonitor (all): \(String(format: "%.2f", sessionDuration))s")
        print("  ─────────────────────────────────────────")
        print("  Parallel max: \(String(format: "%.2f", max(repoDuration, sessionDuration)))s")
        print("  Bottleneck: \(sessionDuration > repoDuration ? "SessionMonitor" : "Repository")")
        print("═══════════════════════════════════════════")

        #expect(entries.count > 0)
        // Session monitor is expected to be the bottleneck
    }

    // MARK: - Warm Cache Performance

    @Test("measures warm cache performance (refresh scenario)")
    func measuresWarmCachePerformance() async throws {
        let repository = UsageRepository(basePath: basePath)
        let sessionService = DefaultSessionMonitorService(configuration: .default)
        let loader = UsageDataLoader(repository: repository, sessionMonitorService: sessionService)

        // Cold load
        let coldStart = Date()
        _ = try await loader.loadToday()
        let coldDuration = Date().timeIntervalSince(coldStart)

        // Warm load (simulates refresh)
        let warmStart = Date()
        _ = try await loader.loadToday()
        let warmDuration = Date().timeIntervalSince(warmStart)

        print("═══════════════════════════════════════════")
        print("Refresh Performance (Warm Cache)")
        print("═══════════════════════════════════════════")
        print("  Cold load: \(String(format: "%.2f", coldDuration))s")
        print("  Warm load: \(String(format: "%.2f", warmDuration))s")
        print("  Speedup: \(String(format: "%.1f", coldDuration / warmDuration))x")
        print("═══════════════════════════════════════════")

        #expect(warmDuration < coldDuration, "Warm cache should be faster")
        #expect(warmDuration < 1.0, "Refresh should be under 1 second")
    }

    // MARK: - Full Load Cycle

    @Test("measures full load cycle (Phase 1 + Phase 2)")
    func measuresFullLoadCycle() async throws {
        let repository = UsageRepository(basePath: basePath)
        let sessionService = DefaultSessionMonitorService(configuration: .default)
        let loader = UsageDataLoader(repository: repository, sessionMonitorService: sessionService)

        let totalStart = Date()

        // Phase 1
        let phase1Start = Date()
        let todayResult = try await loader.loadToday()
        let phase1Duration = Date().timeIntervalSince(phase1Start)

        // Phase 2
        let phase2Start = Date()
        let historyResult = try await loader.loadHistory()
        let phase2Duration = Date().timeIntervalSince(phase2Start)

        let totalDuration = Date().timeIntervalSince(totalStart)

        print("═══════════════════════════════════════════")
        print("Full Load Cycle (App Startup)")
        print("═══════════════════════════════════════════")
        print("  Phase 1 (Today): \(String(format: "%.2f", phase1Duration))s")
        print("  Phase 2 (History): \(String(format: "%.2f", phase2Duration))s")
        print("  ─────────────────────────────────────────")
        print("  Total: \(String(format: "%.2f", totalDuration))s")
        print("  ─────────────────────────────────────────")
        print("  Today entries: \(todayResult.todayEntries.count)")
        print("  Today cost: $\(String(format: "%.2f", todayResult.todayStats.totalCost))")
        print("  Total cost: $\(String(format: "%.2f", historyResult.fullStats.totalCost))")
        print("═══════════════════════════════════════════")

        #expect(todayResult.todayEntries.count > 0)
        #expect(historyResult.fullStats.totalCost > 0)
    }
}
