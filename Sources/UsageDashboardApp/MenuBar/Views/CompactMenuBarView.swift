//
//  CompactMenuBarView.swift
//  Minimal menu bar interface following Mac conventions
//

import SwiftUI
import ClaudeCodeUsage
import ClaudeLiveMonitorLib

// MARK: - View Mode Enum
enum MenuBarDisplayMode: CaseIterable {
    case compact
    case detailed
    
    var displayName: String {
        switch self {
        case .compact: return "Compact"
        case .detailed: return "Detailed"
        }
    }
}

// MARK: - Compact Menu Bar View
struct CompactMenuBarView: View {
    @Environment(UsageDataModel.self) private var dataModel
    @State private var isExpanded = false
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Primary compact view (always visible)
            compactPrimaryView
                .padding(.horizontal, MenuBarTheme.Layout.compactHorizontalPadding)
                .padding(.vertical, MenuBarTheme.Layout.compactVerticalPadding)
            
            // Expanded detailed view (shown on demand)
            if isExpanded {
                Divider()
                    .padding(.horizontal, MenuBarTheme.Layout.compactHorizontalPadding)
                
                expandedDetailView
                    .padding(.horizontal, MenuBarTheme.Layout.compactHorizontalPadding)
                    .padding(.vertical, MenuBarTheme.Layout.compactVerticalPadding)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(width: MenuBarTheme.Layout.compactMenuBarWidth)
        .background(MenuBarTheme.Colors.UI.background)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
    
    // MARK: - Primary Compact View
    private var compactPrimaryView: some View {
        VStack(spacing: MenuBarTheme.Layout.compactItemSpacing) {
            // Primary metrics row
            HStack(alignment: .center) {
                todaysCostView
                Spacer()
                activeSessionIndicator
            }
            
            // Action buttons row
            HStack(spacing: 8) {
                compactActionButton("Refresh", systemImage: "arrow.clockwise") {
                    handleRefresh()
                }
                
                Spacer()
                
                compactActionButton(isExpanded ? "Hide Details" : "Show Details", 
                                   systemImage: isExpanded ? "chevron.up" : "chevron.down") {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }
                
                Menu {
                    Button("Switch to Detailed View") {
                        switchToDetailedMode()
                    }
                    
                    Divider()
                    
                    Button("Preferences...") {
                        #if os(macOS)
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                        #endif
                    }
                    .keyboardShortcut(",", modifiers: .command)
                    
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .keyboardShortcut("q", modifiers: .command)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "gear")
                            .font(.caption)
                        Text("Settings")
                            .font(MenuBarTheme.Typography.compactActionButton)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(MenuBarTheme.Colors.UI.secondaryButtonBackground)
                    .foregroundColor(MenuBarTheme.Colors.UI.secondaryButtonText)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .menuStyle(BorderlessButtonMenuStyle())
            }
        }
    }
    
    // MARK: - Today's Cost View
    private var todaysCostView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Today's Cost")
                .font(MenuBarTheme.Typography.compactPrimaryLabel)
                .foregroundColor(.secondary)
            
            Text(dataModel.formattedTodaysCost ?? "$0.00")
                .font(MenuBarTheme.Typography.compactPrimaryValue)
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Active Session Indicator
    private var activeSessionIndicator: some View {
        Group {
            if let session = dataModel.activeSession, session.isActive {
                HStack(spacing: 6) {
                    Circle()
                        .fill(MenuBarTheme.Colors.Status.active)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isHovered ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: isHovered)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Active Session")
                            .font(MenuBarTheme.Typography.compactStatusBadge)
                            .foregroundColor(.primary)
                        
                        Text(FormatterService.formatTimeInterval(
                            Date().timeIntervalSince(session.startTime),
                            totalInterval: session.endTime.timeIntervalSince(session.startTime)
                        ))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(MenuBarTheme.Colors.Status.active.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onHover { hovering in
                    isHovered = hovering
                }
            } else {
                // Placeholder for consistent layout
                Text("")
                    .font(MenuBarTheme.Typography.compactStatusBadge)
            }
        }
    }
    
    // MARK: - Expanded Detail View
    private var expandedDetailView: some View {
        VStack(spacing: MenuBarTheme.Layout.compactSectionSpacing) {
            // Quick stats summary
            quickStatsRow
            
            // Session details (if active)
            if let session = dataModel.activeSession, session.isActive {
                sessionDetailsView(session)
            }
            
            // Recent activity indicator
            recentActivityView
        }
    }
    
    // MARK: - Quick Stats Row
    private var quickStatsRow: some View {
        HStack(spacing: 16) {
            quickStatItem(
                title: "Sessions",
                value: "\(dataModel.stats?.totalSessions ?? 0)",
                icon: "bubble.left.and.bubble.right"
            )
            
            Divider()
                .frame(height: 20)
            
            quickStatItem(
                title: "Tokens",
                value: FormatterService.formatLargeNumber(dataModel.stats?.totalTokens ?? 0),
                icon: "textformat"
            )
            
            Divider()
                .frame(height: 20)
            
            quickStatItem(
                title: "Total Cost",
                value: dataModel.formattedTotalCost ?? "$0.00",
                icon: "dollarsign.circle"
            )
        }
    }
    
    private func quickStatItem(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Session Details View
    private func sessionDetailsView(_ session: SessionBlock) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text("Session Progress")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            HStack(spacing: 12) {
                // Time progress mini bar
                VStack(alignment: .leading, spacing: 2) {
                    Text("Time")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    ProgressView(value: dataModel.sessionTimeProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: MenuBarTheme.Colors.Status.active))
                        .frame(height: 4)
                }
                
                // Token progress mini bar (if available)
                if dataModel.autoTokenLimit != nil {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tokens")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        ProgressView(value: dataModel.sessionTokenProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: MenuBarTheme.Colors.Status.normal))
                            .frame(height: 4)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(MenuBarTheme.Colors.UI.sectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    // MARK: - Recent Activity View
    private var recentActivityView: some View {
        HStack {
            Image(systemName: "clock")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Last updated: \(FormatterService.formatRelativeTime(dataModel.lastUpdateTime))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if dataModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.7)
            }
        }
    }
    
    // MARK: - Compact Action Button
    private func compactActionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption)
                Text(title)
                    .font(MenuBarTheme.Typography.compactActionButton)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(MenuBarTheme.Colors.UI.secondaryButtonBackground)
            .foregroundColor(MenuBarTheme.Colors.UI.secondaryButtonText)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Actions
    private func handleRefresh() {
        Task {
            await dataModel.loadData()
        }
    }
    
    private func switchToDetailedMode() {
        UserDefaults.standard.menuBarDisplayMode = .detailed
    }
}

// MARK: - Preview
#if DEBUG
#Preview {
    CompactMenuBarView()
        .environment(UsageDataModel(container: TestContainer()))
}
#endif