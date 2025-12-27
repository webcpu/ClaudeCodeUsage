//
//  ClaudeCodeUsageApp.swift
//  Modern SwiftUI app using View + Store + Service architecture
//

import SwiftUI
import Observation
import ClaudeCodeUsageKit

// MARK: - App Entry Point
@main
struct ClaudeCodeUsageApp: App {
    @State private var store = UsageStore()
    @State private var lifecycleManager = AppLifecycleManager()
    @State private var hasAppeared = false
    @State private var settingsService = AppSettingsService()

    var body: some Scene {
        Window("Usage Dashboard", id: "main") {
            MainView(settingsService: settingsService)
                .environment(store)
                .onAppear {
                    guard !hasAppeared else { return }
                    hasAppeared = true
                    lifecycleManager.configure(with: store)
                    Task { await store.initializeIfNeeded() }
                }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 840, height: 600)
        .commands { AppCommands(settingsService: settingsService) }

        MenuBarScene(store: store, settingsService: settingsService)
    }
}

// MARK: - Menu Bar Scene
struct MenuBarScene: Scene {
    let store: UsageStore
    let settingsService: AppSettingsService

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(settingsService: settingsService)
                .environment(store)
        } label: {
            MenuBarLabel(store: store)
                .environment(store)
                .contextMenu {
                    MenuBarContextMenu(settingsService: settingsService)
                        .environment(store)
                }
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Menu Bar Label
struct MenuBarLabel: View {
    let store: UsageStore

    private var appearance: MenuBarAppearance {
        MenuBarAppearance.from(store: store)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: appearance.icon)
                .foregroundColor(appearance.color)
            Text(store.todaysCost)
                .font(.system(.body, design: .monospaced))
        }
    }
}

// MARK: - App Commands
struct AppCommands: Commands {
    let settingsService: AppSettingsService

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Usage Dashboard") {
                settingsService.showAboutPanel()
            }
        }

        CommandGroup(after: .appSettings) {
            OpenAtLoginToggle(settingsService: settingsService)
        }

        CommandMenu("View") {
            Button("Refresh") {
                NotificationCenter.default.post(name: .refreshData, object: nil)
            }
            .keyboardShortcut("R", modifiers: .command)

            Divider()

            Button("Show Main Window") {
                WindowActions.showMainWindow()
            }
            .keyboardShortcut("1", modifiers: .command)
        }
    }
}

// MARK: - Menu Bar Context Menu
struct MenuBarContextMenu: View {
    @Environment(UsageStore.self) private var store
    let settingsService: AppSettingsService

    var body: some View {
        Group {
            Button("Refresh") {
                Task { await store.loadData() }
            }

            Divider()

            if let session = store.activeSession, session.isActive {
                Label("Session Active", systemImage: "dot.radiowaves.left.and.right")
                    .foregroundColor(.green)
            }

            Text("Today: \(store.formattedTodaysCost ?? "$0.00")")

            Divider()

            Button("Open Dashboard") {
                WindowActions.showMainWindow()
            }

            OpenAtLoginToggle(settingsService: settingsService)

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

// MARK: - Pure Transformations

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
        if let session = store.activeSession, session.isActive {
            return .active
        } else if store.todaysCostValue > store.dailyCostThreshold {
            return .warning
        } else {
            return .normal
        }
    }
}

// MARK: - Infrastructure

private enum WindowActions {
    @MainActor
    static func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows
            .first { $0.identifier?.rawValue == "main" }?
            .makeKeyAndOrderFront(nil)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let refreshData = Notification.Name("refreshData")
}
