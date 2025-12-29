//
//  ActionButtons.swift
//  Action buttons component for menu bar
//

import SwiftUI
import ClaudeCodeUsageKit

// MARK: - ActionButtons

struct ActionButtons: View {
    @Environment(\.openWindow) private var openWindow
    let settingsService: AppSettingsService
    let onRefresh: () -> Void
    let viewMode: MenuBarViewMode

    var body: some View {
        HStack(spacing: 12) {
            dashboardButton
            refreshButton
            menuBarOnlyButtons
        }
        .padding(.bottom, MenuBarTheme.Layout.actionButtonsBottomPadding)
    }

    // MARK: - Button Components

    @ViewBuilder
    private var dashboardButton: some View {
        if viewMode == .menuBar {
            Button("Dashboard") {
                openDashboard()
            }
            .buttonStyle(MenuButtonStyle(style: .primary))
            .keyboardShortcut("1", modifiers: .command)
            .help("Open the main dashboard window (⌘1)")
        }
    }

    private var refreshButton: some View {
        Button("Refresh") {
            onRefresh()
        }
        .buttonStyle(MenuButtonStyle(style: .primary))
        .keyboardShortcut("r", modifiers: .command)
        .help("Refresh usage data (⌘R)")
    }

    @ViewBuilder
    private var menuBarOnlyButtons: some View {
        if viewMode == .menuBar {
            settingsMenuButton
            Spacer()
            quitButton
        }
    }

    private var settingsMenuButton: some View {
        SettingsMenu(settingsService: settingsService)
            .menuStyle(BorderlessButtonMenuStyle())
            .fixedSize()
            .buttonStyle(MenuButtonStyle(style: .secondary))
            .help("Settings")
    }

    private var quitButton: some View {
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .buttonStyle(MenuButtonStyle(style: .secondary))
        .keyboardShortcut("q", modifiers: .command)
        .help("Quit the application (⌘Q)")
    }

    // MARK: - Actions

    private func openDashboard() {
        if let existingWindow = findExistingDashboardWindow() {
            bringWindowToFront(existingWindow)
        } else {
            openNewDashboardWindow()
        }
    }

    private func bringWindowToFront(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
    }

    private func openNewDashboardWindow() {
        openWindow(id: "main")
        // Delay activation to allow SwiftUI window to be created
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

// MARK: - Window Helpers

@MainActor
private func findExistingDashboardWindow() -> NSWindow? {
    NSApp.windows.first { isDashboardWindow($0) }
}

@MainActor
private func isDashboardWindow(_ window: NSWindow) -> Bool {
    window.identifier?.rawValue == "main-window" || window.title == "Usage Dashboard"
}

// MARK: - Supporting Types

enum MenuBarViewMode {
    case menuBar
    case liveMetrics
}
