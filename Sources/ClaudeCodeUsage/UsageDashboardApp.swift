//
//  UsageDashboardApp.swift
//  Modern SwiftUI app using View + Store + Service architecture
//

import SwiftUI
import Observation
import ClaudeCodeUsageKit

@main
struct UsageDashboardApp: App {
    @State private var store = UsageStore()
    @State private var lifecycleManager = AppLifecycleManager()
    @State private var hasAppeared = false
    @State private var settingsService = AppSettingsService()

    var body: some Scene {
        Window("Usage Dashboard", id: "main") {
            RootCoordinatorView(settingsService: settingsService)
                .environment(store)
                .onAppear {
                    if !hasAppeared {
                        hasAppeared = true
                        lifecycleManager.configure(with: store)
                        Task {
                            await store.initializeIfNeeded()
                        }
                    }
                }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 840, height: 600)
        .commands {
            AppCommands(settingsService: settingsService)
        }

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

    private var menuBarIcon: String {
        if let session = store.activeSession, session.isActive {
            return "dollarsign.circle.fill"
        } else if store.todaysCostValue > store.dailyCostThreshold {
            return "exclamationmark.triangle.fill"
        } else {
            return "dollarsign.circle"
        }
    }

    private var iconColor: Color {
        if let session = store.activeSession, session.isActive {
            return .green
        } else if store.todaysCostValue > store.dailyCostThreshold {
            return .orange
        } else {
            return .primary
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: menuBarIcon)
                .foregroundColor(iconColor)
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
            Toggle("Open at Login", isOn: Binding(
                get: { settingsService.isOpenAtLoginEnabled },
                set: { newValue in
                    Task {
                        _ = await settingsService.setOpenAtLogin(newValue)
                    }
                }
            ))
        }

        CommandMenu("View") {
            Button("Refresh") {
                NotificationCenter.default.post(name: .refreshData, object: nil)
            }
            .keyboardShortcut("R", modifiers: .command)

            Divider()

            Button("Show Main Window") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
                    window.makeKeyAndOrderFront(nil)
                }
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
                Task {
                    await store.loadData()
                }
            }

            Divider()

            if let session = store.activeSession, session.isActive {
                Label("Session Active", systemImage: "dot.radiowaves.left.and.right")
                    .foregroundColor(.green)
            }

            Text("Today: \(store.formattedTodaysCost ?? "$0.00")")

            Divider()

            Button("Open Dashboard") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }

            Toggle("Open at Login", isOn: Binding(
                get: { settingsService.isOpenAtLoginEnabled },
                set: { newValue in
                    Task {
                        _ = await settingsService.setOpenAtLogin(newValue)
                    }
                }
            ))

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let refreshData = Notification.Name("refreshData")
}
