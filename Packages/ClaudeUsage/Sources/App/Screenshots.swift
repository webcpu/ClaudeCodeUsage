//
//  Screenshots.swift
//  Screenshot provider for ClaudeUsageUI
//
//  Example of ScreenshotProvider for apps with dependencies.
//  For simpler apps, see SimpleScreenshotProvider in ScreenshotKit.
//

import ScreenshotKit
import SwiftUI

// MARK: - Screenshot Provider

public struct Screenshots: ScreenshotProvider {
    public typealias Environment = AppEnvironment

    public static var outputDirectory: URL {
        URL(fileURLWithPath: "/tmp/ClaudeUsageUI")
    }

    public static var screenshots: [Screenshot<Environment>] {
        [
            screenshot("Glance", width: 360, height: 500) { GlanceView() },
            screenshot("Insights-Overview", width: 1100, height: 700) { InsightsView(initialDestination: .overview) },
            screenshot("Insights-DailyUsage", width: 1100, height: 700) { InsightsView(initialDestination: .dailyUsage) },
            screenshot("Insights-Analytics", width: 1100, height: 700) { InsightsView(initialDestination: .analytics) }
        ]
    }

    public static func makeEnvironment() async throws -> Environment {
        let env = AppEnvironment.live()
        await env.glanceStore.loadData()
        await env.insightsStore.loadData()

        // Wait for data to load (max 5 seconds)
        for _ in 0..<50 {
            if !env.glanceStore.isLoading && !env.insightsStore.isLoading { return env }
            try await Task.sleep(for: .milliseconds(100))
        }

        struct TimeoutError: Error {}
        throw TimeoutError()
    }
}

// MARK: - Helpers

private func screenshot<V: View>(
    _ name: String,
    width: CGFloat,
    height: CGFloat,
    @ViewBuilder _ view: @escaping @MainActor @Sendable () -> V
) -> Screenshot<AppEnvironment> {
    .init(name: name, width: width, height: height) { env in
        AnyView(
            view()
                .environment(env.glanceStore)
                .environment(env.insightsStore)
                .environment(env.settings)
                .environment(\.isCaptureMode, true)
        )
    }
}
