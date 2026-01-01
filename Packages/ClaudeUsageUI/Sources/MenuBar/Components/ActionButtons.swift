//
//  ActionButtons.swift
//  Action buttons component for menu bar
//

import SwiftUI
import ClaudeUsageCore

// MARK: - ActionButtons

struct ActionButtons: View {
    @Environment(\.openWindow) private var openWindow
    let viewMode: MenuBarViewMode

    var body: some View {
        HStack(spacing: 12) {
            dashboardButton
            menuBarOnlyButtons
        }
        .padding(.bottom, MenuBarTheme.Layout.actionButtonsBottomPadding)
    }

    // MARK: - Button Components

    @ViewBuilder
    private var dashboardButton: some View {
        if viewMode == .menuBar {
            Button("Main") {
                openMainWindow()
            }
            .buttonStyle(MenuButtonStyle(style: .primary))
            .keyboardShortcut("1", modifiers: .command)
            .help("Open the main window (⌘1)")
        }
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
        SettingsMenu()
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

    private func openMainWindow() {
        let targetScreen = captureCurrentScreen()
        requestMainWindowOpen()
        positionWindowAfterCreation(on: targetScreen)
    }

    private func captureCurrentScreen() -> NSScreen? {
        screenAtMouseLocation()
    }

    private func requestMainWindowOpen() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func positionWindowAfterCreation(on targetScreen: NSScreen?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard let window = findMainWindow() else { return }
            bringWindowToFront(window)
            centerWindowOnNextRunLoop(window, on: targetScreen)
        }
    }
}

// MARK: - Window Helpers

@MainActor
private func findMainWindow() -> NSWindow? {
    NSApp.windows.first { $0.title == AppMetadata.name }
}

@MainActor
private func screenAtMouseLocation() -> NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
        ?? NSScreen.main
}

@MainActor
private func bringWindowToFront(_ window: NSWindow) {
    window.collectionBehavior.insert(.moveToActiveSpace)
    if window.isMiniaturized {
        window.deminiaturize(nil)
    }
    window.makeKeyAndOrderFront(nil)
}

@MainActor
private func centerWindowOnNextRunLoop(_ window: NSWindow, on screen: NSScreen?) {
    DispatchQueue.main.async {
        centerWindow(window, on: screen)
    }
}

@MainActor
private func centerWindow(_ window: NSWindow, on screen: NSScreen?) {
    guard let screen = screen else { return }
    let screenFrame = screen.visibleFrame
    let windowSize = window.frame.size
    let x = screenFrame.midX - windowSize.width / 2
    let y = screenFrame.midY - windowSize.height / 2
    window.setFrame(NSRect(x: x, y: y, width: windowSize.width, height: windowSize.height), display: true)
}

// MARK: - Supporting Types

enum MenuBarViewMode {
    case menuBar
    case liveMetrics
}
