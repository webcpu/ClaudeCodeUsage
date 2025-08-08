//
//  MenuBar.swift
//  Refactored professional menu bar UI with clean architecture
//

import SwiftUI
import ClaudeCodeUsage

// MARK: - Main Menu Bar Content View
struct MenuBarContentView: View {
    @Environment(UsageDataModel.self) private var dataModel
    
    var body: some View {
        VStack(spacing: 2) {
            // Live Session Section
            if let session = dataModel.activeSession, session.isActive {
                SectionHeader(
                    title: "Live Session",
                    icon: "dot.radiowaves.left.and.right",
                    color: MenuBarTheme.Colors.Sections.liveSession,
                    badge: "ACTIVE"
                )
                
                SessionMetricsSection()
                
                sectionDivider
            }
            
            // Usage Section
            SectionHeader(
                title: "Usage",
                icon: "chart.bar.fill",
                color: MenuBarTheme.Colors.Sections.usage,
                badge: nil
            )
            
            UsageMetricsSection()
            
            sectionDivider
            
            // Cost Section
            SectionHeader(
                title: "Cost",
                icon: "dollarsign.circle.fill",
                color: MenuBarTheme.Colors.Sections.cost,
                badge: nil
            )
            
            CostMetricsSection()
            
            largeDivider
            
            // Actions
            ActionButtons {
                handleRefresh()
            }
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
