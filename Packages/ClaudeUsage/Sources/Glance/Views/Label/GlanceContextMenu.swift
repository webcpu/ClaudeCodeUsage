//
//  GlanceContextMenu.swift
//  Context menu for menu bar right-click
//

import SwiftUI

// MARK: - Glance Context Menu

struct GlanceContextMenu: View {
    @Environment(GlanceStore.self) private var store

    var body: some View {
        Group {
            statusSection
            Divider()
            actionsSection
            Divider()
            quitButton
        }
    }

    private var statusSection: some View {
        Group {
            sessionIndicator
            Text("Today: \(store.formattedTodaysCost)")
        }
    }

    @ViewBuilder
    private var sessionIndicator: some View {
        if let session = store.activeSession, session.isActive {
            Label("Session Active", systemImage: "dot.radiowaves.left.and.right")
                .foregroundColor(.green)
        }
    }

    private var actionsSection: some View {
        Group {
            Button("Main") { WindowActions.showMainWindow() }
            OpenAtLoginToggle()
        }
    }

    private var quitButton: some View {
        Button("Quit") { NSApplication.shared.terminate(nil) }
    }
}
