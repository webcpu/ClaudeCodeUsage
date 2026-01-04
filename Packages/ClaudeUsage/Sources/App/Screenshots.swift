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
            screenshot("MenuBar", width: 360, height: 500) { MenuBarContentView() },
            screenshot("MainWindow-Overview", width: 1100, height: 700) { MainView(initialDestination: .overview) },
            screenshot("MainWindow-Models", width: 1100, height: 700) { MainView(initialDestination: .models) },
            screenshot("MainWindow-DailyUsage", width: 1100, height: 700) { MainView(initialDestination: .dailyUsage) },
            screenshot("MainWindow-Analytics", width: 1100, height: 700) { MainView(initialDestination: .analytics) },
            screenshot("MainWindow-LiveMetrics", width: 1100, height: 700) { MainView(initialDestination: .liveMetrics) },
        ]
    }

    public static func makeEnvironment() async throws -> Environment {
        let env = AppEnvironment.live()
        await env.sessionStore.loadData()
        await env.analyticsStore.loadData()

        // Wait for data to load (max 5 seconds)
        for _ in 0..<50 {
            if !env.sessionStore.isLoading && !env.analyticsStore.isLoading { return env }
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
                .environment(env.sessionStore)
                .environment(env.analyticsStore)
                .environment(env.settings)
                .environment(\.isCaptureMode, true)
        )
    }
}
