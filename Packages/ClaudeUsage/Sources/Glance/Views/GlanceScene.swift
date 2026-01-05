//
//  GlanceScene.swift
//  Glance scene and supporting views
//

import SwiftUI

// MARK: - Glance Scene

public struct GlanceScene: Scene {
    let env: AppEnvironment
    let lifecycleManager: AppLifecycleManager
    @State private var hasInitialized = false

    public init(env: AppEnvironment, lifecycleManager: AppLifecycleManager) {
        self.env = env
        self.lifecycleManager = lifecycleManager
    }

    public var body: some Scene {
        MenuBarExtra {
            menuContent
        } label: {
            menuLabel
        }
        .menuBarExtraStyle(.window)
    }

    private var menuContent: some View {
        GlanceView()
            .environment(env.glanceStore)
            .environment(env.settings)
    }

    private var menuLabel: some View {
        GlanceLabel(store: env.glanceStore)
            .id(env.glanceStore.formattedTodaysCost)
            .environment(env.glanceStore)
            .environment(env.settings)
            .task { await initializeOnce() }
            .contextMenu { contextMenu }
    }

    private var contextMenu: some View {
        GlanceContextMenu()
            .environment(env.glanceStore)
            .environment(env.settings)
    }

    private func initializeOnce() async {
        guard !hasInitialized else { return }
        hasInitialized = true
        lifecycleManager.configure(with: env.glanceStore)
        await env.glanceStore.initializeIfNeeded()
    }
}
