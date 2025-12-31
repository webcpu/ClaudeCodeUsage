//
//  AppEnvironment+Capture.swift
//  Capture manifest for ClaudeUsageUI
//

import SwiftUI

// MARK: - Capture Manifest Conformance

extension AppEnvironment: CaptureManifest {
    public static var outputDirectory: URL {
        URL(fileURLWithPath: "/tmp/ClaudeUsageUI")
    }

    public static var targets: [CaptureTarget<AppEnvironment>] {
        [
            .init(name: "MenuBar", width: 360, height: 500) { env in
                AnyView(
                    MenuBarContentView()
                        .withAppEnvironment(env)
                        .environment(\.isCaptureMode, true)
                )
            },
            .init(name: "MainWindow-Overview", width: 1100, height: 700) { env in
                AnyView(
                    MainView(initialDestination: .overview)
                        .withAppEnvironment(env)
                        .environment(\.isCaptureMode, true)
                )
            },
            .init(name: "MainWindow-Models", width: 1100, height: 700) { env in
                AnyView(
                    MainView(initialDestination: .models)
                        .withAppEnvironment(env)
                        .environment(\.isCaptureMode, true)
                )
            },
            .init(name: "MainWindow-DailyUsage", width: 1100, height: 700) { env in
                AnyView(
                    MainView(initialDestination: .dailyUsage)
                        .withAppEnvironment(env)
                        .environment(\.isCaptureMode, true)
                )
            },
            .init(name: "MainWindow-Analytics", width: 1100, height: 700) { env in
                AnyView(
                    MainView(initialDestination: .analytics)
                        .withAppEnvironment(env)
                        .environment(\.isCaptureMode, true)
                )
            },
            .init(name: "MainWindow-LiveMetrics", width: 1100, height: 700) { env in
                AnyView(
                    MainView(initialDestination: .liveMetrics)
                        .withAppEnvironment(env)
                        .environment(\.isCaptureMode, true)
                )
            },
        ]
    }

    public static func makeEnvironment() async throws -> AppEnvironment {
        let env = AppEnvironment.live()
        await env.store.loadData()

        for _ in 0..<50 {
            if env.store.state.hasLoaded { return env }
            try await Task.sleep(for: .milliseconds(100))
        }

        struct DataNotLoaded: Error {}
        throw DataNotLoaded()
    }
}
