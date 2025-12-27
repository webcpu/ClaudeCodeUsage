//
//  MenuBar.swift
//  Refactored professional menu bar UI with clean architecture
//

import SwiftUI
import ClaudeCodeUsageKit

// MARK: - Main Menu Bar Content View
struct MenuBarContentView: View {
    @Environment(UsageStore.self) private var store
    let settingsService: AppSettingsService
    @FocusState private var focusedField: FocusField?
    let viewMode: MenuBarViewMode
    
    enum FocusField: Hashable {
        case refresh
        case settings
        case quit
    }
    
    // MARK: - Initializers
    init(settingsService: AppSettingsService, viewMode: MenuBarViewMode = .menuBar) {
        self.settingsService = settingsService
        self.viewMode = viewMode
    }
    
    var body: some View {
        VStack(spacing: 0) {
            liveSessionSection
            usageSection
            costSection
            systemSection
            actionsSection
        }
        .frame(width: MenuBarTheme.Layout.menuBarWidth)
        .background(MenuBarTheme.Colors.UI.background)
        .focusable()
        .onKeyPress { handleKeyPress($0) }
    }

    // MARK: - Sections

    @ViewBuilder
    private var liveSessionSection: some View {
        if let session = store.activeSession, session.isActive {
            SectionHeader(
                title: "Live Session",
                icon: "dot.radiowaves.left.and.right",
                color: MenuBarTheme.Colors.Sections.liveSession,
                badge: "ACTIVE"
            )
            SessionMetricsSection()
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            sectionDivider
                .padding(.horizontal, 12)
        }
    }

    private var usageSection: some View {
        Group {
            SectionHeader(
                title: "Usage",
                icon: "chart.bar.fill",
                color: MenuBarTheme.Colors.Sections.usage,
                badge: nil
            )
            UsageMetricsSection()
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            sectionDivider
                .padding(.horizontal, 12)
        }
    }

    private var costSection: some View {
        Group {
            SectionHeader(
                title: "Cost",
                icon: "dollarsign.circle.fill",
                color: MenuBarTheme.Colors.Sections.cost,
                badge: nil
            )
            CostMetricsSection()
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            sectionDivider
                .padding(.horizontal, 12)
        }
    }

    private var systemSection: some View {
        Group {
            SectionHeader(
                title: "System",
                icon: "memorychip",
                color: MenuBarTheme.Colors.Sections.system,
                badge: nil
            )
            MemoryMonitorView()
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            largeDivider
                .padding(.horizontal, 12)
        }
    }

    private var actionsSection: some View {
        ActionButtons(settingsService: settingsService, onRefresh: handleRefresh, viewMode: viewMode)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
    }

    // MARK: - Keyboard Handling

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .tab:
            press.modifiers.contains(.shift) ? switchFocusPrevious() : switchFocusNext()
            return .handled
        case .escape:
            if viewMode == .menuBar { NSApp.hide(nil) }
            return .handled
        case KeyEquivalent("r") where press.modifiers.contains(.command):
            handleRefresh()
            return .handled
        default:
            return .ignored
        }
    }
    
    // MARK: - Focus Navigation
    private func switchFocusNext() {
        switch focusedField {
        case .refresh:
            focusedField = .settings
        case .settings:
            focusedField = .quit
        case .quit, nil:
            focusedField = .refresh
        }
    }
    
    private func switchFocusPrevious() {
        switch focusedField {
        case .refresh:
            focusedField = .quit
        case .settings:
            focusedField = .refresh
        case .quit, nil:
            focusedField = .settings
        }
    }
    
    // MARK: - UI Elements
    private var sectionDivider: some View {
        Divider()
            .padding(.vertical, MenuBarTheme.Layout.dividerVerticalPadding)
    }
    
    private var largeDivider: some View {
        Divider()
            .padding(.vertical, MenuBarTheme.Layout.verticalPadding)
    }
    
    // MARK: - Actions
    private func handleRefresh() {
        Task {
            await store.loadData()
        }
    }
}

// MARK: - Backward Compatibility Aliases
// These maintain compatibility with existing code that may reference the old component names
typealias ImprovedProgressBar = ProgressBar
typealias EnhancedGraphView = GraphView
typealias ImprovedSectionHeader = SectionHeader
