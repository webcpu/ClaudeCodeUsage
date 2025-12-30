//
//  ClaudeCodeUsageApp.swift
//  Modern SwiftUI app using View + Store + Service architecture
//

import SwiftUI
import Observation
import ClaudeUsageCore

// MARK: - Layout Constants

private enum Layout {
    static let menuBarSpacing: CGFloat = 4
    static let windowWidth: CGFloat = 840
    static let windowHeight: CGFloat = 600
}

// MARK: - App Entry Point

@main
struct ClaudeCodeUsageApp: App {
    @State private var store = UsageStore()
    @State private var lifecycleManager = AppLifecycleManager()
    @State private var settingsService = AppSettingsService()

    var body: some Scene {
        mainWindow
        menuBarScene
    }

    private var mainWindow: some Scene {
        Window(AppMetadata.name, id: "main") {
            MainView(settingsService: settingsService)
                .environment(store)
        }
        .defaultLaunchBehavior(.suppressed)
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .defaultSize(width: Layout.windowWidth, height: Layout.windowHeight)
        .commands { AppCommands(settingsService: settingsService) }
    }

    private var menuBarScene: some Scene {
        MenuBarScene(store: store, settingsService: settingsService, lifecycleManager: lifecycleManager)
    }
}

// MARK: - Menu Bar Scene

struct MenuBarScene: Scene {
    let store: UsageStore
    let settingsService: AppSettingsService
    let lifecycleManager: AppLifecycleManager
    @State private var hasInitialized = false

    var body: some Scene {
        MenuBarExtra {
            menuContent
        } label: {
            menuLabel
        }
        .menuBarExtraStyle(.window)
    }

    private var menuContent: some View {
        MenuBarContentView(settingsService: settingsService)
            .environment(store)
    }

    private var menuLabel: some View {
        MenuBarLabel(store: store)
            .environment(store)
            .task { await initializeOnce() }
            .contextMenu { contextMenu }
    }

    private var contextMenu: some View {
        MenuBarContextMenu(settingsService: settingsService)
            .environment(store)
    }

    private func initializeOnce() async {
        guard !hasInitialized else { return }
        hasInitialized = true
        lifecycleManager.configure(with: store)
        await store.initializeIfNeeded()
    }
}

// MARK: - Menu Bar Label

struct MenuBarLabel: View {
    let store: UsageStore

    var body: some View {
        HStack(spacing: Layout.menuBarSpacing) {
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

// MARK: - App Commands

struct AppCommands: Commands {
    let settingsService: AppSettingsService

    var body: some Commands {
        aboutCommand
        settingsCommand
        viewMenu
    }

    private var aboutCommand: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About \(AppMetadata.name)") {
                settingsService.showAboutPanel()
            }
        }
    }

    private var settingsCommand: some Commands {
        CommandGroup(after: .appSettings) {
            OpenAtLoginToggle(settingsService: settingsService)
        }
    }

    private var viewMenu: some Commands {
        CommandMenu("View") {
            refreshButton
            Divider()
            showWindowButton
        }
    }

    private var refreshButton: some View {
        Button("Refresh") {
            NotificationCenter.default.post(name: .refreshData, object: nil)
        }
        .keyboardShortcut("R", modifiers: .command)
    }

    private var showWindowButton: some View {
        Button("Show Main Window") {
            WindowActions.showMainWindow()
        }
        .keyboardShortcut("1", modifiers: .command)
    }
}

// MARK: - Menu Bar Context Menu

struct MenuBarContextMenu: View {
    @Environment(UsageStore.self) private var store
    let settingsService: AppSettingsService

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
            OpenAtLoginToggle(settingsService: settingsService)
        }
    }

    private var quitButton: some View {
        Button("Quit") { NSApplication.shared.terminate(nil) }
    }
}

// MARK: - Menu Bar Appearance

@MainActor
private enum MenuBarAppearance {
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

private extension UsageStore {
    var hasActiveSession: Bool {
        activeSession?.isActive == true
    }

    var isOverBudget: Bool {
        todaysCost > dailyCostThreshold
    }
}

// MARK: - Window Actions

private enum WindowActions {
    @MainActor
    static func showMainWindow() {
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

// MARK: - Notification Names

extension Notification.Name {
    static let refreshData = Notification.Name("refreshData")
}
