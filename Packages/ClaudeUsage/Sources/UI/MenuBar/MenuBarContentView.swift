//
//  MenuBar.swift
//  Refactored professional menu bar UI with clean architecture
//

import SwiftUI
import ClaudeUsageCore

// MARK: - Main Menu Bar Content View
struct MenuBarContentView: View {
    @Environment(UsageStore.self) private var store
    @Environment(AppSettingsService.self) private var settings
    @FocusState private var focusedField: FocusField?
    let viewMode: MenuBarViewMode

    enum FocusField: Hashable {
        case settings
        case quit
    }

    init(viewMode: MenuBarViewMode = .menuBar) {
        self.viewMode = viewMode
    }
    
    var body: some View {
        VStack(spacing: 0) {
            liveSessionSection
            usageSection
            costSection
            actionsSection
        }
        .frame(width: MenuBarTheme.Layout.menuBarWidth)
        .background(MenuBarTheme.Colors.UI.background)
        .focusable()
        .onKeyPress { handleKeyPress($0) }
        .task { await store.initializeIfNeeded() }
    }

    // MARK: - Sections

    @ViewBuilder
    private var liveSessionSection: some View {
        if let session = store.activeSession {
            let _ = session  // Suppress unused warning
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

    @ViewBuilder
    private var usageSection: some View {
        if store.activeSession != nil {
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

    private var actionsSection: some View {
        ActionButtons(viewMode: viewMode)
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
        default:
            return .ignored
        }
    }
    
    // MARK: - Focus Navigation
    private func switchFocusNext() {
        switch focusedField {
        case .settings:
            focusedField = .quit
        case .quit, nil:
            focusedField = .settings
        }
    }

    private func switchFocusPrevious() {
        switch focusedField {
        case .settings:
            focusedField = .quit
        case .quit, nil:
            focusedField = .settings
        }
    }
    
    // MARK: - UI Elements
    private var sectionDivider: some View {
        Divider()
            .padding(.vertical, MenuBarTheme.Layout.dividerVerticalPadding)
    }
}

// MARK: - Backward Compatibility Aliases
// These maintain compatibility with existing code that may reference the old component names
typealias ImprovedProgressBar = ProgressBar
typealias EnhancedGraphView = GraphView
typealias ImprovedSectionHeader = SectionHeader
