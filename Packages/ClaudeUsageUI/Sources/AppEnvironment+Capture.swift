//
//  AppEnvironment+Capture.swift
//  Capture manifest for ClaudeUsageUI
//
//  Example of CaptureManifest for apps with dependencies.
//  For simpler apps, see SimpleCaptureManifest in PreviewCaptureKit.
//

import PreviewCaptureKit
import SwiftUI

// MARK: - Capture Manifest

public struct ClaudeUsageUICaptures: CaptureManifest {
    public typealias Environment = AppEnvironment

    public static var outputDirectory: URL {
        URL(fileURLWithPath: "/tmp/ClaudeUsageUI")
    }

    public static var targets: [CaptureTarget<AppEnvironment>] {
        [
            capture("MenuBar", width: 360, height: 500) { MenuBarContentView() },
            capture("MainWindow-Overview", width: 1100, height: 700) { MainView(initialDestination: .overview) },
            capture("MainWindow-Models", width: 1100, height: 700) { MainView(initialDestination: .models) },
            capture("MainWindow-DailyUsage", width: 1100, height: 700) { MainView(initialDestination: .dailyUsage) },
            capture("MainWindow-Analytics", width: 1100, height: 700) { MainView(initialDestination: .analytics) },
            capture("MainWindow-LiveMetrics", width: 1100, height: 700) { MainView(initialDestination: .liveMetrics) },
        ]
    }

    public static func makeEnvironment() async throws -> AppEnvironment {
        let env = AppEnvironment.live()
        await env.store.loadData()

        // Wait for data to load (max 5 seconds)
        for _ in 0..<50 {
            if env.store.state.hasLoaded { return env }
            try await Task.sleep(for: .milliseconds(100))
        }

        struct TimeoutError: Error {}
        throw TimeoutError()
    }
}

// MARK: - Helpers

private func capture<V: View>(
    _ name: String,
    width: CGFloat,
    height: CGFloat,
    @ViewBuilder _ view: @escaping @MainActor @Sendable () -> V
) -> CaptureTarget<AppEnvironment> {
    .init(name: name, width: width, height: height) { env in
        AnyView(
            view()
                .environment(env.store)
                .environment(env.settings)
                .environment(\.isCaptureMode, true)
        )
    }
}
