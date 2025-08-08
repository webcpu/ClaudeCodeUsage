//
//  ActionButtons.swift
//  Action buttons component for menu bar
//

import SwiftUI
import ClaudeCodeUsage

struct ActionButtons: View {
    @Environment(\.openWindow) private var openWindow
    let onRefresh: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
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
            
            Button("Refresh") {
                onRefresh()
            }
            .buttonStyle(MenuButtonStyle(style: .primary))
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(MenuButtonStyle(style: .secondary))
        }
        .padding(.horizontal, MenuBarTheme.Layout.horizontalPadding)
        .padding(.bottom, MenuBarTheme.Layout.actionButtonsBottomPadding)
    }
}