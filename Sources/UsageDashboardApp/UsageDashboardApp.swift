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
    
    var body: some Scene {
        WindowGroup(id: "main") {
            RootCoordinatorView()
                .environment(appState.dataModel)
                .onAppear {
                    lifecycleManager.configure(with: appState.dataModel)
                }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands {
            AppCommands()
        }
        
        MenuBarScene(appState: appState)
    }
}

// MARK: - Menu Bar Scene
struct MenuBarScene: Scene {
    let appState: AppState
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environment(appState.dataModel)
        } label: {
            MenuBarLabel(appState: appState)
                .environment(appState.dataModel)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Menu Bar Label
struct MenuBarLabel: View {
    @Environment(UsageDataModel.self) private var dataModel
    let appState: AppState
    
    var body: some View {
        HStack(spacing: 4) {
            if let session = dataModel.activeSession, session.isActive {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
            }
            Image(systemName: "dollarsign.circle.fill")
            Text(dataModel.todaysCost)
                .font(.system(.body, design: .monospaced))
        }
        .task {
            await appState.initializeIfNeeded()
        }
    }
}

// MARK: - App Commands
struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Usage Dashboard") {
                NSApp.orderFrontStandardAboutPanel(
                    options: [
                        .applicationName: "Usage Dashboard",
                        .applicationVersion: "1.0.0",
                        .credits: NSAttributedString(
                            string: "Claude Code Usage Tracking",
                            attributes: [.font: NSFont.systemFont(ofSize: 11)]
                        )
                    ]
                )
            }
        }
        
        CommandMenu("View") {
            Button("Refresh") {
                NotificationCenter.default.post(name: .refreshData, object: nil)
            }
            .keyboardShortcut("R", modifiers: .command)
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

// MARK: - Notification Names
extension Notification.Name {
    static let refreshData = Notification.Name("refreshData")
}