//
//  MenuBarScene.swift
//  Menu bar scene and supporting views
//

import SwiftUI
import ClaudeUsageCore

// MARK: - Preview Detection

private let isRunningForPreviews = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"

// MARK: - Menu Bar Scene

public struct MenuBarScene: Scene {
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

    @ViewBuilder
    private var menuContent: some View {
        if isRunningForPreviews {
            Text("Preview Mode")
                .frame(width: 200, height: 100)
        } else {
            MenuBarContentView()
                .withAppEnvironment(env)
        }
    }

    @ViewBuilder
    private var menuLabel: some View {
        if isRunningForPreviews {
            Image(systemName: "dollarsign.circle")
        } else {
            MenuBarLabel(store: env.store)
                .withAppEnvironment(env)
                .task { await initializeOnce() }
                .contextMenu { contextMenu }
        }
    }

    private var contextMenu: some View {
        MenuBarContextMenu()
            .withAppEnvironment(env)
    }

    private func initializeOnce() async {
        guard !hasInitialized else { return }
        hasInitialized = true
        lifecycleManager.configure(with: env.store)
        await env.store.initializeIfNeeded()
    }
}

// MARK: - Menu Bar Label

struct MenuBarLabel: View {
    let store: UsageStore

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

    private var appearance: MenuBarAppearance {
        MenuBarAppearance.from(store: store)
    }
}

// MARK: - Menu Bar Context Menu

struct MenuBarContextMenu: View {
    @Environment(UsageStore.self) private var store

    var body: some View {
        Group {
            refreshSection
            Divider()
            statusSection
            Divider()
            actionsSection
            Divider()
            quitButton
        }
    }

    private var refreshSection: some View {
        Button("Refresh") {
            Task { await store.loadData() }
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

// MARK: - Menu Bar Appearance

@MainActor
enum MenuBarAppearance {
    case active
    case warning
    case normal

    var icon: String {
        switch self {
        case .active: "dollarsign.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .normal: "dollarsign.circle"
        }
    }

    var color: Color {
        switch self {
        case .active: .green
        case .warning: .orange
        case .normal: .primary
        }
    }

    static func from(store: UsageStore) -> MenuBarAppearance {
        if store.hasActiveSession { return .active }
        if store.isOverBudget { return .warning }
        return .normal
    }
}

// MARK: - UsageStore Appearance Helpers

extension UsageStore {
    var hasActiveSession: Bool {
        activeSession?.isActive == true
    }

    var isOverBudget: Bool {
        todaysCost > dailyCostThreshold
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Menu Bar Label", traits: .sizeThatFitsLayout) {
    MenuBarLabel(store: UsageStore())
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(8)
        .frame(width: 200, height: 100)
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
