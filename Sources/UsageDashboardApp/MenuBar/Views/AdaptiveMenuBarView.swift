//
//  AdaptiveMenuBarView.swift
//  Adaptive menu bar that switches between compact and detailed modes
//

import SwiftUI
import ClaudeCodeUsage
import ClaudeLiveMonitorLib

// MARK: - User Defaults Keys
extension UserDefaults {
    private enum Keys {
        static let menuBarDisplayMode = "menuBarDisplayMode"
    }
    
    var menuBarDisplayMode: MenuBarDisplayMode {
        get {
            let rawValue = string(forKey: Keys.menuBarDisplayMode) ?? "compact"
            return MenuBarDisplayMode(rawValue: rawValue) ?? .compact
        }
        set {
            set(newValue.rawValue, forKey: Keys.menuBarDisplayMode)
        }
    }
}

extension MenuBarDisplayMode: RawRepresentable {
    public var rawValue: String {
        switch self {
        case .compact: return "compact"
        case .detailed: return "detailed"
        }
    }
    
    public init?(rawValue: String) {
        switch rawValue {
        case "compact": self = .compact
        case "detailed": self = .detailed
        default: return nil
        }
    }
}

// MARK: - Adaptive Menu Bar View
struct AdaptiveMenuBarView: View {
    @Environment(UsageDataModel.self) private var dataModel
    @AppStorage("menuBarDisplayMode") private var displayMode: MenuBarDisplayMode = .compact // Default to compact mode
    
    var body: some View {
        Group {
            switch displayMode {
            case .compact:
                CompactMenuBarView()
            case .detailed:
                DetailedMenuBarView()
            }
        }
        .background(MenuBarTheme.Colors.UI.background)
    }
}

// MARK: - Detailed Menu Bar View (Current Implementation)
struct DetailedMenuBarView: View {
    @Environment(UsageDataModel.self) private var dataModel
    let viewMode: MenuBarViewMode
    
    init(viewMode: MenuBarViewMode = .menuBar) {
        self.viewMode = viewMode
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with mode toggle
            detailedViewHeader
            
            Divider()
            
            // Original detailed content
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
                ActionButtons(onRefresh: handleRefresh, viewMode: viewMode)
            }
            .padding(.horizontal, MenuBarTheme.Layout.horizontalPadding)
            .padding(.vertical, MenuBarTheme.Layout.verticalPadding)
        }
        .frame(width: MenuBarTheme.Layout.menuBarWidth)
        .background(MenuBarTheme.Colors.UI.background)
    }
    
    // MARK: - Detailed View Header
    private var detailedViewHeader: some View {
        HStack {
            Text("Claude Usage Analytics")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: { switchToCompactMode() }) {
                HStack(spacing: 4) {
                    Image(systemName: "minus.square")
                        .font(.caption)
                    Text("Compact")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, MenuBarTheme.Layout.horizontalPadding)
        .padding(.vertical, 8)
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
    
    private func switchToCompactMode() {
        UserDefaults.standard.menuBarDisplayMode = .compact
    }
}

// MARK: - Settings View for Mode Selection
struct MenuBarModeSettingsView: View {
    @AppStorage("menuBarDisplayMode") private var displayMode: MenuBarDisplayMode = .compact
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Menu Bar Display")
                .font(.headline)
            
            Picker("Display Mode", selection: $displayMode) {
                ForEach(MenuBarDisplayMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Group {
                switch displayMode {
                case .compact:
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Compact Mode")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Shows only essential information (today's cost + active session). Click 'Show Details' for analytics.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                case .detailed:
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Detailed Mode")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Shows full analytics dashboard with charts and metrics. More information but takes more menu bar space.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding()
    }
}

// MARK: - Preview
#if DEBUG
#Preview("Adaptive Menu Bar") {
    AdaptiveMenuBarView()
        .environment(UsageDataModel(container: TestContainer()))
}
#endif

#Preview("Settings") {
    MenuBarModeSettingsView()
}