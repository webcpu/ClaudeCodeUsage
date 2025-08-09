//
//  UsageDashboardApp.swift
//  Modern SwiftUI app using @Observable
//

import SwiftUI
import Observation
import ClaudeCodeUsage

@main
struct UsageDashboardApp: App {
    @State private var appState = AppState()
    @State private var lifecycleManager = AppLifecycleManager()
    @State private var hasAppeared = false
    @StateObject private var settingsService = AppSettingsService()
    
    var body: some Scene {
        Window("Usage Dashboard", id: "main") {
            RootCoordinatorView(settingsService: settingsService)
                .environment(appState.dataModel)
                .onAppear {
                    if !hasAppeared {
                        hasAppeared = true
                        lifecycleManager.configure(with: appState.dataModel)
                        Task {
                            await appState.initializeIfNeeded()
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
        
        MenuBarScene(appState: appState, settingsService: settingsService)
    }
}

// MARK: - Menu Bar Scene
struct MenuBarScene: Scene {
    let appState: AppState
    @ObservedObject var settingsService: AppSettingsService
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(settingsService: settingsService)
                .environment(appState.dataModel)
        } label: {
            MenuBarLabel(appState: appState)
                .environment(appState.dataModel)
                .contextMenu {
                    MenuBarContextMenu(settingsService: settingsService)
                        .environment(appState.dataModel)
                }
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Menu Bar Label
struct MenuBarLabel: View {
    @Environment(UsageDataModel.self) private var dataModel
    let appState: AppState
    
    private var menuBarIcon: String {
        // Dynamic icon based on state
        if let session = dataModel.activeSession, session.isActive {
            return "dollarsign.circle.fill" // Active session
        } else if dataModel.todaysCostValue > dataModel.dailyCostThreshold {
            return "exclamationmark.triangle.fill" // Cost warning
        } else {
            return "dollarsign.circle" // Normal state
        }
    }
    
    private var iconColor: Color {
        if let session = dataModel.activeSession, session.isActive {
            return .green
        } else if dataModel.todaysCostValue > dataModel.dailyCostThreshold {
            return .orange
        } else {
            return .primary
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: menuBarIcon)
                .foregroundColor(iconColor)
            Text(dataModel.todaysCost)
                .font(.system(.body, design: .monospaced))
        }
    }
}

// MARK: - App Commands
struct AppCommands: Commands {
    @ObservedObject var settingsService: AppSettingsService
    
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

// MARK: - App State
@Observable
@MainActor
final class AppState {
    let dataModel: UsageDataModel
    private var hasInitialized = false
    
    init() {
        self.dataModel = UsageDataModel(container: ProductionContainer.shared)
    }
    
    func initializeIfNeeded() async {
        guard !hasInitialized else { return }
        hasInitialized = true
        
        await dataModel.loadData()
        dataModel.startRefreshTimer()
    }
}

// MARK: - Menu Bar Context Menu
struct MenuBarContextMenu: View {
    @Environment(UsageDataModel.self) private var dataModel
    @ObservedObject var settingsService: AppSettingsService
    
    var body: some View {
        Group {
            Button("Refresh") {
                Task {
                    await dataModel.loadData()
                }
            }
            
            Divider()
            
            if let session = dataModel.activeSession, session.isActive {
                Label("Session Active", systemImage: "dot.radiowaves.left.and.right")
                    .foregroundColor(.green)
            }
            
            Text("Today: \(dataModel.formattedTodaysCost ?? "$0.00")")
            
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
