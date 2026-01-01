//
//  AppEnvironment.swift
//  Single container for all app dependencies
//

import SwiftUI

// MARK: - App Environment

@MainActor
public struct AppEnvironment: @unchecked Sendable {
    public let store: UsageStore
    public let settings: AppSettingsService

    public init(store: UsageStore = UsageStore(), settings: AppSettingsService = AppSettingsService()) {
        self.store = store
        self.settings = settings
    }

    public static func live() -> AppEnvironment {
        AppEnvironment()
    }
}

// MARK: - View Extension

public extension View {
    func withAppEnvironment(_ env: AppEnvironment) -> some View {
        self
            .environment(env.store)
            .environment(env.settings)
    }
}

// MARK: - Preview Modifier

#if DEBUG
public struct PreviewEnvironment: PreviewModifier {
    public static func makeSharedContext() async throws -> AppEnvironment {
        let env = AppEnvironment.live()
        await env.store.loadData()
        return env
    }

    public func body(content: Content, context: AppEnvironment) -> some View {
        content.withAppEnvironment(context)
    }
}

public extension PreviewTrait where T == Preview.ViewTraits {
    static var appEnvironment: PreviewTrait<T> {
        .modifier(PreviewEnvironment())
    }
}
#endif
