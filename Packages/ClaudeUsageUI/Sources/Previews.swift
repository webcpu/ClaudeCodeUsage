//
//  Previews.swift
//  All app previews in one place
//

#if DEBUG
import SwiftUI
import ClaudeUsageCore

// MARK: - Menu Bar Preview

struct MenuBarPreviewWrapper: View {
    @State private var store = UsageStore()

    var body: some View {
        content
            .frame(height: 500)
            .task { await store.loadData() }
    }

    @ViewBuilder
    private var content: some View {
        if store.state.hasLoaded {
            MenuBarContentView(settingsService: AppSettingsService())
                .environment(store)
        } else {
            ProgressView("Loading...")
                .frame(width: MenuBarTheme.Layout.menuBarWidth, height: 200)
        }
    }
}

// MARK: - Main Window Preview

struct MainWindowPreviewWrapper: View {
    @State private var store = UsageStore()

    var body: some View {
        MainView(settingsService: AppSettingsService())
            .environment(store)
            .frame(width: 1000, height: 700)
            .task { await store.loadData() }
    }
}

// MARK: - Previews

#Preview("Menu Bar") {
    MenuBarPreviewWrapper()
}

#Preview("Main Window") {
    MainWindowPreviewWrapper()
}

#Preview("All") {
    HStack {
        MenuBarPreviewWrapper()
        Divider()
        MainWindowPreviewWrapper()
    }
}
#endif
