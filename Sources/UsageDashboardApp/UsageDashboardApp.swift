//
//  UsageDashboardApp.swift
//  Clean architecture main app entry point
//

import SwiftUI
import ClaudeCodeUsage

@main
struct UsageDashboardApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var lifecycleManager = AppLifecycleManager()
    
    var body: some Scene {
        WindowGroup(id: "main") {
            RootCoordinatorView()
                .environmentObject(appState.dataModel)
                .onAppear {
                    lifecycleManager.configure(with: appState.dataModel)
                }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands {
            AppCommands()
        }
        
        if #available(macOS 13.0, *) {
            MenuBarScene(appState: appState)
        }
    }
}


// MARK: - Menu Bar Scene
@available(macOS 13.0, *)
struct MenuBarScene: Scene {
    let appState: AppState
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(appState.dataModel)
        } label: {
            MenuBarLabel()
                .environmentObject(appState.dataModel)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Menu Bar Label
@available(macOS 13.0, *)
struct MenuBarLabel: View {
    @EnvironmentObject var dataModel: UsageDataModel
    
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
@MainActor
final class AppState: ObservableObject {
    let dataModel: UsageDataModel
    
    init() {
        self.dataModel = UsageDataModel(container: ProductionContainer.shared)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let refreshData = Notification.Name("refreshData")
}