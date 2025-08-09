//
//  ActionButtons.swift
//  Action buttons component for menu bar
//

import SwiftUI
import ClaudeCodeUsage

// MARK: - View Mode
enum MenuBarViewMode {
    case menuBar    // Full interface with all buttons (menu bar dropdown)
    case liveMetrics // Clean interface without Dashboard/Quit buttons (Live Metrics view)
}

struct ActionButtons: View {
    @Environment(\.openWindow) private var openWindow
    let onRefresh: () -> Void
    let viewMode: MenuBarViewMode
    
    var body: some View {
        HStack(spacing: 12) {
            // Dashboard button - only show in menu bar mode
            if viewMode == .menuBar {
                Button("Dashboard") {
                    // Check if a window already exists
                    if let existingWindow = NSApp.windows.first(where: { window in
                        window.identifier?.rawValue == "main-window" ||
                        window.title == "Usage Dashboard"
                    }) {
                        // Bring existing window to front
                        existingWindow.makeKeyAndOrderFront(nil)
                        NSApp.activate(ignoringOtherApps: true)
                    } else {
                        // Open new window only if none exists
                        openWindow(id: "main")
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
                .buttonStyle(MenuButtonStyle(style: .primary))
            }
            
            Button("Refresh") {
                onRefresh()
            }
            .buttonStyle(MenuButtonStyle(style: .primary))
            
            // Quit button - only show in menu bar mode
            if viewMode == .menuBar {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(MenuButtonStyle(style: .secondary))
            }
        }
        .padding(.bottom, MenuBarTheme.Layout.actionButtonsBottomPadding)
    }
}