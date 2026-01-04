//
//  ClaudeCodeUsageApp.swift
//  App entry point
//

import SwiftUI
import ClaudeUsage

// MARK: - App Entry Point

@main
struct ClaudeCodeUsageApp: App {
    @State private var env = AppEnvironment.live()
    @State private var lifecycleManager = AppLifecycleManager()

    var body: some Scene {
        mainWindow
        menuBarScene
    }

    private var mainWindow: some Scene {
        Window(AppMetadata.name, id: "main") {
            MainView()
                .environment(env.store)
                .environment(env.settings)
        }
        .defaultLaunchBehavior(.suppressed)
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 840, height: 600)
        .commands { AppCommands(settings: env.settings) }
    }

    private var menuBarScene: some Scene {
        MenuBarScene(env: env, lifecycleManager: lifecycleManager)
    }
}

// MARK: - App Commands

struct AppCommands: Commands {
    let settings: AppSettingsService

    var body: some Commands {
        aboutCommand
        settingsCommand
        viewMenu
    }

    private var aboutCommand: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About \(AppMetadata.name)") {
                settings.showAboutPanel()
            }
        }
    }

    private var settingsCommand: some Commands {
        CommandGroup(after: .appSettings) {
            OpenAtLoginToggle()
                .environment(settings)
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

