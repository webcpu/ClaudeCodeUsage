//
//  MenuBarTheme.swift
//  Centralized theme and design constants for the menu bar
//

import SwiftUI

@available(macOS 13.0, *)
struct MenuBarTheme {
    
    // MARK: - Layout Constants
    struct Layout {
        // Menu Bar Width
        static let menuBarWidth: CGFloat = 360
        
        // Padding
        static let horizontalPadding: CGFloat = 20
        static let contentHorizontalPadding: CGFloat = 12  // Reduced padding for content sections
        static let verticalPadding: CGFloat = 10
        
        // Spacing
        static let sectionSpacing: CGFloat = 14
        static let itemSpacing: CGFloat = 8
        static let dividerVerticalPadding: CGFloat = 6
        static let actionButtonsBottomPadding: CGFloat = 14
        
        // Progress Bar
        static let progressBarHeight: CGFloat = 10
        static let progressBarCornerRadius: CGFloat = 4
        
        // Graph
        static let graphHeight: CGFloat = 45
        static let graphCornerRadius: CGFloat = 6
        static let graphWidth: CGFloat = 100
        static let largeGraphWidth: CGFloat = 200
        static let costGraphHeight: CGFloat = 50
        
        // Dots
        static let dataDotSize: CGFloat = 4
        static let gridLineCount: Int = 4
    }
    
    // MARK: - Typography
    struct Typography {
        // Regular Typography
        static let sectionTitle = Font.system(size: 10, weight: .semibold)
        static let sectionTitleKerning: CGFloat = 0.8
        
        static let metricTitle = Font.system(size: 11)
        static let metricValue = Font.system(size: 15, weight: .semibold, design: .rounded)
        static let metricSubvalue = Font.system(size: 9)
        static let summaryValue = Font.system(size: 12, weight: .medium)
        static let summaryLabel = Font.system(size: 10)
        
        static let burnRateLabel = Font.system(size: 11)
        static let burnRateValue = Font.system(size: 11, weight: .medium)
        
        static let actionButton = Font.system(size: 11, weight: .medium)
        
        static let badgeText = Font.system(size: 9, weight: .medium)
        static let sectionIcon = Font.system(size: 12, weight: .medium)
        static let warningIcon = Font.system(size: 11)
        static let overflowIcon = Font.system(size: 8)
    }
    
    // MARK: - Colors
    struct Colors {
        // Progress Bar Segments
        struct ProgressSegments {
            static let green = Color.green
            static let orange = Color.orange
            static let red = Color.red
            static let blue = Color.blue
            static let purple = Color.purple
        }
        
        // Status Colors
        struct Status {
            static let active = Color.green
            static let warning = Color.orange
            static let critical = Color.red
            static let normal = Color.blue
        }
        
        // UI Colors
        struct UI {
            static let background = Color(NSColor.controlBackgroundColor)
            static let secondaryText = Color.secondary
            static let primaryText = Color.primary
            
            static let trackBackground = Color.gray.opacity(0.1)
            static let trackBorder = Color.gray.opacity(0.2)
            static let sectionBackground = Color.gray.opacity(0.05)
            
            static let primaryButtonBackground = Color.blue.opacity(0.1)
            static let primaryButtonBorder = Color.blue.opacity(0.3)
            static let primaryButtonText = Color.blue
            
            static let secondaryButtonBackground = Color.gray.opacity(0.1)
            static let secondaryButtonBorder = Color.gray.opacity(0.2)
            static let secondaryButtonText = Color.primary
            
            static let gridLines = Color.gray.opacity(0.1)
        }
        
        // Section Colors
        struct Sections {
            static let liveSession = Color.green
            static let usage = Color.blue
            static let cost = Color.purple
        }
    }
    
    // MARK: - Performance Thresholds
    struct Thresholds {
        struct Percentage {
            static let low: Double = 60.0
            static let medium: Double = 80.0
            static let high: Double = 100.0
        }
        
        struct Cost {
            static let normal: Double = 0.6
            static let warning: Double = 0.8
            static let critical: Double = 1.0
        }
        
        struct Sessions {
            static let timeSegments = (low: 0.7, medium: 0.9, max: 1.5)
            static let tokenSegments = (low: 0.6, medium: 0.85, max: 1.5)
        }
    }
    
    // MARK: - Animation
    struct Animation {
        static let buttonPress = SwiftUI.Animation.easeInOut(duration: 0.1)
        static let scalePressed: CGFloat = 0.95
        static let scaleNormal: CGFloat = 1.0
    }
    
    // MARK: - Button Styles
    struct Button {
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 6
        static let cornerRadius: CGFloat = 6
        static let borderWidth: CGFloat = 1
    }
    
    // MARK: - Badge
    struct Badge {
        static let horizontalPadding: CGFloat = 6
        static let verticalPadding: CGFloat = 2
        static let cornerRadius: CGFloat = 4
    }
    
    // MARK: - Graph Properties
    struct Graph {
        static let lineWidth: CGFloat = 2
        static let strokeWidth: CGFloat = 0.5
        static let minimumRange: Double = 0.01
        static let areaGradientTopOpacity: Double = 0.3
        static let areaGradientBottomOpacity: Double = 0.05
        static let progressGradientStartOpacity: Double = 0.8
        static let progressGradientEndOpacity: Double = 1.0
    }
}