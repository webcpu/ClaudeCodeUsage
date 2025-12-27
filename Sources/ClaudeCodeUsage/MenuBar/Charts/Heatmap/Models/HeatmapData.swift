//
//  HeatmapData.swift
//  Data models for heatmap visualization
//
//  Provides type-safe data structures for representing heatmap information
//  with optimized caching and pre-computed values for performance.
//

import SwiftUI
import Foundation

// MARK: - Date Formatting Helpers

private enum HeatmapDateFormatter {
    private static let idFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    static func stableIdentifier(for date: Date) -> String {
        idFormatter.string(from: date)
    }

    static func displayString(for date: Date) -> String {
        displayFormatter.string(from: date)
    }

    static func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}

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

    /// Pre-computed color for light mode (legacy - use color(for:) for scheme-aware color)
    public let color: Color

    /// Intensity level (0.0 to 1.0) relative to the maximum cost
    public let intensity: Double

    /// Discrete intensity level (0-4) for color lookup
    public let intensityLevel: Int

    // MARK: - Initialization

    public init(
        date: Date,
        cost: Double,
        dayOfYear: Int,
        weekOfYear: Int,
        dayOfWeek: Int,
        maxCost: Double
    ) {
        self.id = HeatmapDateFormatter.stableIdentifier(for: date)
        self.date = date
        self.cost = cost
        self.dayOfYear = dayOfYear
        self.weekOfYear = weekOfYear
        self.dayOfWeek = dayOfWeek

        self.isEmpty = cost == 0
        self.isToday = HeatmapDateFormatter.isToday(date)
        self.dateString = HeatmapDateFormatter.displayString(for: date)
        self.costString = cost > 0 ? cost.asCurrency : "No usage"

        self.intensity = IntensityLevelCalculator.intensity(cost: cost, maxCost: maxCost)
        self.intensityLevel = IntensityLevelCalculator.level(for: self.intensity)
        self.color = HeatmapColorScheme.color(for: cost, maxCost: maxCost)
    }

    // MARK: - Color Scheme Support

    /// Returns the appropriate color for the given color scheme
    public func color(for scheme: ColorScheme) -> Color {
        HeatmapColorScheme.color(for: intensityLevel, scheme: scheme)
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

// MARK: - Intensity Level Calculation (Pure Functions)

private enum IntensityLevelCalculator {
    /// Thresholds for each level (checked in order)
    static let thresholds: [(range: PartialRangeFrom<Double>, level: Int)] = [
        (0.75..., 4),  // High
        (0.5..., 3),   // Medium-high
        (0.25..., 2),  // Medium-low
        (0.0..., 1)    // Low (anything > 0)
    ]

    /// Convert intensity (0.0-1.0) to discrete level (0-4)
    static func level(for intensity: Double) -> Int {
        intensity == 0 ? 0 : (thresholds.first { $0.range.contains(intensity) }?.level ?? 1)
    }

    /// Calculate intensity from cost
    static func intensity(cost: Double, maxCost: Double) -> Double {
        maxCost > 0 ? min(cost / maxCost, 1.0) : 0.0
    }
}

// MARK: - Color Scheme

/// Optimized color scheme for heatmap visualization with light/dark mode support
public enum HeatmapColorScheme {

    // MARK: - Light Mode Colors (GitHub Light Theme)

    /// Colors for light mode (5 levels from no activity to high activity)
    public static let lightColors: [Color] = [
        Color(red: 235/255, green: 237/255, blue: 240/255),  // Level 0: #ebedf0
        Color(red: 155/255, green: 233/255, blue: 168/255),  // Level 1: #9be9a8
        Color(red: 64/255, green: 196/255, blue: 99/255),    // Level 2: #40c463
        Color(red: 48/255, green: 161/255, blue: 78/255),    // Level 3: #30a14e
        Color(red: 33/255, green: 110/255, blue: 57/255)     // Level 4: #216e39
    ]

    // MARK: - Dark Mode Colors (GitHub Dark Theme)

    /// Colors for dark mode (5 levels from no activity to high activity)
    public static let darkColors: [Color] = [
        Color(red: 22/255, green: 27/255, blue: 34/255),     // Level 0: #161b22
        Color(red: 14/255, green: 68/255, blue: 41/255),     // Level 1: #0e4429
        Color(red: 0/255, green: 109/255, blue: 50/255),     // Level 2: #006d32
        Color(red: 38/255, green: 166/255, blue: 65/255),    // Level 3: #26a641
        Color(red: 57/255, green: 211/255, blue: 83/255)     // Level 4: #39d353
    ]

    // MARK: - Legacy Support

    /// Legacy color array (light mode) - kept for backward compatibility
    @available(*, deprecated, message: "Use colors(for:) with ColorScheme instead")
    public static var legendColors: [Color] { lightColors }

    // MARK: - Color Calculation

    /// Returns colors for the specified color scheme
    public static func colors(for scheme: ColorScheme) -> [Color] {
        scheme == .dark ? darkColors : lightColors
    }

    /// Returns the appropriate color for a given level and color scheme
    public static func color(for level: Int, scheme: ColorScheme) -> Color {
        let colors = colors(for: scheme)
        let index = max(0, min(colors.count - 1, level))
        return colors[index]
    }

    /// Returns the appropriate color for a given cost value (light mode - legacy)
    public static func color(for cost: Double, maxCost: Double) -> Color {
        let level = intensityLevel(for: cost, maxCost: maxCost)
        return lightColors[level]
    }

    /// Returns the appropriate color for a given cost value and color scheme
    public static func color(for cost: Double, maxCost: Double, scheme: ColorScheme) -> Color {
        let level = intensityLevel(for: cost, maxCost: maxCost)
        return color(for: level, scheme: scheme)
    }

    /// Returns the intensity level (0-4) for legend purposes
    public static func intensityLevel(for cost: Double, maxCost: Double) -> Int {
        let intensity = IntensityLevelCalculator.intensity(cost: cost, maxCost: maxCost)
        return IntensityLevelCalculator.level(for: intensity)
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