//
//  ActionButtons.swift
//  Action buttons component for menu bar
//

import SwiftUI
import ClaudeCodeUsage

@available(macOS 13.0, *)
struct ActionButtons: View {
    @EnvironmentObject var dataModel: UsageDataModel
    @Environment(\.openWindow) private var openWindow
    let onRefresh: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button("Dashboard") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
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