//
//  HeatmapData.swift
//  Data models for heatmap visualization
//
//  Provides type-safe data structures for representing heatmap information
//  with optimized caching and pre-computed values for performance.
//

import SwiftUI
import Foundation

// MARK: - Core Data Models

/// Represents a single day in the heatmap with pre-computed display values for performance
public struct HeatmapDay: Identifiable, Equatable, Hashable {
    
    // MARK: - Identification & Core Data
    
    /// Stable date-based identifier to prevent SwiftUI view recreation
    public let id: String
    
    /// The date this day represents
    public let date: Date
    
    /// The cost value for this day
    public let cost: Double
    
    // MARK: - Calendar Properties
    
    /// Day of the year (1-366)
    public let dayOfYear: Int
    
    /// Week number within the heatmap
    public let weekOfYear: Int
    
    /// Day of the week (0=Sunday, 6=Saturday)
    public let dayOfWeek: Int
    
    // MARK: - Display Properties
    
    /// Whether this day has no usage (cost == 0)
    public let isEmpty: Bool
    
    /// Whether this day is today
    public let isToday: Bool
    
    /// Pre-formatted date string for display (e.g., "Jan 15, 2024")
    public let dateString: String
    
    /// Pre-formatted cost string for display (e.g., "$1.23" or "No usage")
    public let costString: String
    
    /// Pre-computed color to avoid repeated calculations during rendering
    public let color: Color
    
    /// Intensity level (0.0 to 1.0) relative to the maximum cost
    public let intensity: Double
    
    // MARK: - Initialization
    
    public init(
        date: Date,
        cost: Double,
        dayOfYear: Int,
        weekOfYear: Int,
        dayOfWeek: Int,
        maxCost: Double
    ) {
        // Create stable date-based ID
        let idFormatter = DateFormatter()
        idFormatter.dateFormat = "yyyy-MM-dd"
        self.id = idFormatter.string(from: date)
        
        self.date = date
        self.cost = cost
        self.dayOfYear = dayOfYear
        self.weekOfYear = weekOfYear
        self.dayOfWeek = dayOfWeek
        
        // Computed properties
        self.isEmpty = cost == 0
        
        // Check if this is today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dayStart = calendar.startOfDay(for: date)
        self.isToday = dayStart == today
        
        // Pre-format strings to avoid repeated formatting during hover
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM d, yyyy"
        self.dateString = displayFormatter.string(from: date)
        self.costString = cost > 0 ? cost.asCurrency : "No usage"
        
        // Calculate intensity and pre-compute color
        self.intensity = maxCost > 0 ? min(cost / maxCost, 1.0) : 0.0
        self.color = HeatmapColorScheme.color(for: cost, maxCost: maxCost)
    }
    
    // MARK: - Equatable & Hashable
    
    public static func == (lhs: HeatmapDay, rhs: HeatmapDay) -> Bool {
        lhs.id == rhs.id && lhs.cost == rhs.cost
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(cost)
    }
}

/// Represents a week in the heatmap containing up to 7 days
public struct HeatmapWeek: Identifiable, Equatable {
    
    /// Stable week-based identifier
    public let id: String
    
    /// Week number within the heatmap
    public let weekNumber: Int
    
    /// Array of 7 days (some may be nil for partial weeks)
    public let days: [HeatmapDay?]
    
    /// Total cost for this week
    public let totalCost: Double
    
    /// Number of days with usage in this week
    public let daysWithUsage: Int
    
    public init(weekNumber: Int, days: [HeatmapDay?]) {
        self.id = "week-\(weekNumber)"
        self.weekNumber = weekNumber
        self.days = days
        
        // Calculate derived properties
        self.totalCost = days.compactMap { $0?.cost }.reduce(0, +)
        self.daysWithUsage = days.compactMap { $0 }.filter { !$0.isEmpty }.count
    }
}

/// Represents a month label in the heatmap
public struct HeatmapMonth: Identifiable, Equatable {
    
    /// Stable month-based identifier
    public let id: String
    
    /// Short month name (e.g., "Jan", "Feb")
    public let name: String
    
    /// Range of week indices this month spans
    public let weekSpan: Range<Int>
    
    /// Full month name (e.g., "January", "February")
    public let fullName: String
    
    /// Month number (1-12)
    public let monthNumber: Int
    
    /// Year this month belongs to
    public let year: Int
    
    public init(name: String, weekSpan: Range<Int>, fullName: String = "", monthNumber: Int = 0, year: Int = 0) {
        self.id = "month-\(name)-\(year)"
        self.name = name
        self.weekSpan = weekSpan
        self.fullName = fullName.isEmpty ? name : fullName
        self.monthNumber = monthNumber
        self.year = year
    }
}

// MARK: - Heatmap Dataset

/// Complete dataset for heatmap visualization
public struct HeatmapDataset: Equatable {
    
    /// Array of weeks containing the heatmap data
    public let weeks: [HeatmapWeek]
    
    /// Array of month labels for the header
    public let monthLabels: [HeatmapMonth]
    
    /// Maximum cost value across all days (used for color scaling)
    public let maxCost: Double
    
    /// Date range covered by this dataset
    public let dateRange: ClosedRange<Date>
    
    /// Total cost across all days
    public let totalCost: Double
    
    /// Total number of days with usage
    public let daysWithUsage: Int
    
    /// All days flattened from weeks (excluding nil days)
    public var allDays: [HeatmapDay] {
        weeks.flatMap { $0.days.compactMap { $0 } }
    }
    
    public init(
        weeks: [HeatmapWeek],
        monthLabels: [HeatmapMonth],
        maxCost: Double,
        dateRange: ClosedRange<Date>
    ) {
        self.weeks = weeks
        self.monthLabels = monthLabels
        self.maxCost = maxCost
        self.dateRange = dateRange
        
        // Calculate derived properties
        let allDays = weeks.flatMap { $0.days.compactMap { $0 } }
        self.totalCost = allDays.reduce(0) { $0 + $1.cost }
        self.daysWithUsage = allDays.filter { !$0.isEmpty }.count
    }
}

// MARK: - Color Scheme

/// Optimized color scheme for heatmap visualization
public enum HeatmapColorScheme {
    
    // MARK: - Color Constants
    
    /// Color for days with no usage
    public static let emptyColor = Color(red: 240/255, green: 242/255, blue: 245/255)
    
    /// Color for low usage days
    public static let lowColor = Color(red: 186/255, green: 236/255, blue: 191/255)
    
    /// Color for medium-low usage days
    public static let mediumLowColor = Color(red: 109/255, green: 191/255, blue: 116/255)
    
    /// Color for medium-high usage days
    public static let mediumHighColor = Color(red: 83/255, green: 162/255, blue: 88/255)
    
    /// Color for high usage days
    public static let highColor = Color(red: 45/255, green: 97/255, blue: 48/255)
    
    /// Array of all legend colors (5 levels from no activity to high activity)
    public static let legendColors: [Color] = [
        emptyColor,      // Level 0: No contributions
        lowColor,        // Level 1: Low contributions
        mediumLowColor,  // Level 2: Medium-low contributions
        mediumHighColor, // Level 3: Medium-high contributions
        highColor        // Level 4: High contributions
    ]
    
    // MARK: - Color Calculation
    
    /// Returns the appropriate color for a given cost value
    /// - Parameters:
    ///   - cost: The cost value for the day
    ///   - maxCost: The maximum cost value for scaling
    /// - Returns: Pre-computed color for optimal performance
    public static func color(for cost: Double, maxCost: Double) -> Color {
        if cost == 0 { return emptyColor }
        
        let intensity = maxCost > 0 ? min(cost / maxCost, 1.0) : 0.0
        
        // Use pre-computed colors to avoid repeated Color.green.opacity() calls
        switch intensity {
        case 0..<0.25:
            return lowColor
        case 0.25..<0.5:
            return mediumLowColor
        case 0.5..<0.75:
            return mediumHighColor
        default:
            return highColor
        }
    }
    
    /// Returns the intensity level (0-4) for legend purposes
    public static func intensityLevel(for cost: Double, maxCost: Double) -> Int {
        if cost == 0 { return 0 }
        
        let intensity = maxCost > 0 ? min(cost / maxCost, 1.0) : 0.0
        
        switch intensity {
        case 0..<0.25:
            return 1
        case 0.25..<0.5:
            return 2
        case 0.5..<0.75:
            return 3
        default:
            return 4
        }
    }
}

// MARK: - Extensions

/// Safe array access extension
public extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

/// Double extension for currency formatting
public extension Double {
    var asCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
    }
}