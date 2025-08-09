//
//  MenuBar.swift
//  Refactored professional menu bar UI with clean architecture
//

import SwiftUI
import ClaudeCodeUsage

// MARK: - Main Menu Bar Content View
struct MenuBarContentView: View {
    @Environment(UsageDataModel.self) private var dataModel
    let viewMode: MenuBarViewMode
    
    // MARK: - Initializers
    init(viewMode: MenuBarViewMode = .menuBar) {
        self.viewMode = viewMode
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Live Session Section
            if let session = dataModel.activeSession, session.isActive {
                SectionHeader(
                    title: "Live Session",
                    icon: "dot.radiowaves.left.and.right",
                    color: MenuBarTheme.Colors.Sections.liveSession,
                    badge: "ACTIVE"
                )
                
                SessionMetricsSection()
                    .padding(.horizontal, MenuBarTheme.Layout.horizontalPadding)
                    .padding(.vertical, 4)
                
                sectionDivider
                    .padding(.horizontal, MenuBarTheme.Layout.horizontalPadding)
            }
            
            // Usage Section
            SectionHeader(
                title: "Usage",
                icon: "chart.bar.fill",
                color: MenuBarTheme.Colors.Sections.usage,
                badge: nil
            )
            
            UsageMetricsSection()
                .padding(.horizontal, MenuBarTheme.Layout.horizontalPadding)
                .padding(.vertical, 4)
            
            sectionDivider
                .padding(.horizontal, MenuBarTheme.Layout.horizontalPadding)
            
            // Cost Section
            SectionHeader(
                title: "Cost",
                icon: "dollarsign.circle.fill",
                color: MenuBarTheme.Colors.Sections.cost,
                badge: nil
            )
            
            CostMetricsSection()
                .padding(.horizontal, MenuBarTheme.Layout.horizontalPadding)
                .padding(.vertical, 4)
            
            largeDivider
                .padding(.horizontal, MenuBarTheme.Layout.horizontalPadding)
            
            // Actions
            ActionButtons(onRefresh: handleRefresh, viewMode: viewMode)
                .padding(.horizontal, MenuBarTheme.Layout.horizontalPadding)
                .padding(.bottom, 8)
        }
        .frame(width: MenuBarTheme.Layout.menuBarWidth)
        .background(MenuBarTheme.Colors.UI.background)
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
            await dataModel.loadData()
        }
    }
}

// MARK: - Backward Compatibility Aliases
// These maintain compatibility with existing code that may reference the old component names
typealias ImprovedProgressBar = ProgressBar
typealias EnhancedGraphView = GraphView
typealias ImprovedSectionHeader = SectionHeader
