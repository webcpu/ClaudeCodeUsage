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

// MARK: - Glance Label

struct GlanceLabel: View {
    @Bindable var store: GlanceStore

    var body: some View {
        HStack(spacing: 4) {
            iconView
            costText
        }
    }

    private var iconView: some View {
        Image(systemName: appearance.icon)
            .foregroundColor(appearance.color)
    }

    private var costText: some View {
        Text(store.formattedTodaysCost)
            .font(.system(.body, design: .monospaced))
    }

    private var appearance: GlanceAppearanceConfig {
        GlanceAppearanceRegistry.select(from: store)
    }
}

// MARK: - Glance Context Menu

struct GlanceContextMenu: View {
    @Environment(GlanceStore.self) private var store

    var body: some View {
        Group {
            statusSection
            Divider()
            actionsSection
            Divider()
            quitButton
        }
    }

    private var statusSection: some View {
        Group {
            sessionIndicator
            Text("Today: \(store.formattedTodaysCost)")
        }
    }

    @ViewBuilder
    private var sessionIndicator: some View {
        if let session = store.activeSession, session.isActive {
            Label("Session Active", systemImage: "dot.radiowaves.left.and.right")
                .foregroundColor(.green)
        }
    }

    private var actionsSection: some View {
        Group {
            Button("Main") { WindowActions.showMainWindow() }
            OpenAtLoginToggle()
        }
    }

    private var quitButton: some View {
        Button("Quit") { NSApplication.shared.terminate(nil) }
    }
}

// MARK: - Glance Appearance

/// Configuration for a glance appearance state.
/// Registry pattern: each appearance is a configuration bundle, not a switch case.
struct GlanceAppearanceConfig {
    let icon: String
    let color: Color
}

/// Registry of glance appearance configurations.
/// Open for extension (add new appearances), closed for modification (no switch changes needed).
@MainActor
enum GlanceAppearanceRegistry {
    static let active = GlanceAppearanceConfig(
        icon: "dollarsign.circle.fill",
        color: .green
    )

    static let warning = GlanceAppearanceConfig(
        icon: "exclamationmark.triangle.fill",
        color: .orange
    )

    static let normal = GlanceAppearanceConfig(
        icon: "dollarsign.circle",
        color: .primary
    )

    /// Selects the appropriate appearance configuration based on store state.
    static func select(from store: GlanceStore) -> GlanceAppearanceConfig {
        if store.hasActiveSession { return active }
        return normal
    }
}

// MARK: - GlanceStore Appearance Helpers

extension GlanceStore {
    var hasActiveSession: Bool {
        activeSession?.isActive == true
    }
}

// MARK: - Preview

#if DEBUG
private struct GlanceLabelPreview: View {
    @Environment(GlanceStore.self) private var store

    var body: some View {
        GlanceLabel(store: store)
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            .cornerRadius(8)
            .frame(width: 200, height: 100)
    }
}

#Preview("Glance Label", traits: .appEnvironment) {
    GlanceLabelPreview()
}
#endif

// MARK: - Window Actions

public enum WindowActions {
    @MainActor
    public static func showMainWindow() {
        let targetScreen = captureScreenAtMouseLocation()
        activateApp()
        findAndShowWindow(on: targetScreen)
    }

    @MainActor
    private static func captureScreenAtMouseLocation() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main
    }

    @MainActor
    private static func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    private static func findAndShowWindow(on targetScreen: NSScreen?) {
        guard let window = NSApp.windows.first(where: { $0.title == AppMetadata.name }) else { return }
        moveToActiveSpace(window)
        restoreIfMinimized(window)
        window.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { centerWindow(window, on: targetScreen) }
    }

    @MainActor
    private static func moveToActiveSpace(_ window: NSWindow) {
        window.collectionBehavior.insert(.moveToActiveSpace)
    }

    @MainActor
    private static func restoreIfMinimized(_ window: NSWindow) {
        if window.isMiniaturized { window.deminiaturize(nil) }
    }

    @MainActor
    private static func centerWindow(_ window: NSWindow, on screen: NSScreen?) {
        guard let screen else { return }
        let frame = screen.visibleFrame
        let size = window.frame.size
        let origin = CGPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2)
        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}
