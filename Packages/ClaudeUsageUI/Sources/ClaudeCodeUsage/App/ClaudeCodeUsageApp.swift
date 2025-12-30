//
//  ClaudeCodeUsageApp.swift
//  App entry point
//

import SwiftUI
import ClaudeUsageCore
import ClaudeUsageUI

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
        .defaultSize(width: 840, height: 600)
        .commands { AppCommands(settingsService: settingsService) }
    }

    private var menuBarScene: some Scene {
        MenuBarScene(store: store, settingsService: settingsService, lifecycleManager: lifecycleManager)
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

