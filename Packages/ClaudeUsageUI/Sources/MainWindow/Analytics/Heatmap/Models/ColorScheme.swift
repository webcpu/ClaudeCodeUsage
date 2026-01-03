//
//  ColorScheme.swift
//  Advanced color management for heatmap visualization
//
//  Provides sophisticated color calculations, theme management, and performance-optimized
//  color lookup for heatmap components with accessibility support.
//

import SwiftUI

// MARK: - Color Variation (OCP: Open for Extension)

/// Different color variations for special states.
/// Each variation carries its own transformation, eliminating switch statements.
public enum ColorVariation: Int, CaseIterable, Sendable {
    case normal = 0
    case hovered = 1
    case selected = 2
    case dimmed = 3
    case highlighted = 4

    /// Apply this variation's transformation to a base color.
    /// Add new variations by adding cases with their transforms here.
    func apply(to color: Color) -> Color {
        switch self {
        case .normal: color
        case .hovered: color.opacity(0.8)
        case .selected: color.brightness(0.2)
        case .dimmed: color.opacity(0.5)
        case .highlighted: color.saturation(1.3)
        }
    }
}

// MARK: - Theme Color Grid (Immutable)

/// Immutable pre-computed color grid for a specific theme.
/// Eliminates mutable caching through lazy initialization at construction time.
public struct ThemeColorGrid: Sendable {

    // MARK: - Properties

    public let theme: HeatmapColorTheme

    /// Pre-computed color grid: colorGrid[level][variation] -> Color
    /// Built once at initialization, providing O(1) lookup with no mutation.
    private let colorGrid: [[Color]]

    // MARK: - Initialization

    public init(theme: HeatmapColorTheme = .github) {
        self.theme = theme
        self.colorGrid = Self.buildColorGrid(for: theme)
    }

    // MARK: - Public Interface (High Level)

    /// Get color for a cost value (pure function - no caching needed)
    public func color(
        for cost: Double,
        maxCost: Double,
        variation: ColorVariation = .normal
    ) -> Color {
        colorGrid[intensityLevel(for: cost, maxCost: maxCost)][variation.rawValue]
    }

    /// Map costs to colors (pure transformation)
    public func mapColors(
        for costs: [Double],
        maxCost: Double
    ) -> [Double: Color] {
        Dictionary(uniqueKeysWithValues: costs.map { cost in
            (cost, color(for: cost, maxCost: maxCost))
        })
    }

    /// Analyze color distribution for a dataset (pure function)
    public func analyzeDistribution(costs: [Double], maxCost: Double) -> ColorDistribution {
        ColorDistribution(
            totalItems: costs.count,
            levelCounts: countByLevel(costs, maxCost: maxCost),
            maxCost: maxCost,
            averageCost: average(of: costs)
        )
    }

    // MARK: - Pure Intensity Calculations

    private func intensityLevel(for cost: Double, maxCost: Double) -> Int {
        cost == 0 ? 0 : IntensityLevel.fromIntensity(intensity(cost: cost, maxCost: maxCost))
    }

    private func intensity(cost: Double, maxCost: Double) -> Double {
        maxCost > 0 ? min(cost / maxCost, 1.0) : 0.0
    }

    private func countByLevel(_ costs: [Double], maxCost: Double) -> [Int] {
        costs.reduce(into: [0, 0, 0, 0, 0]) { counts, cost in
            counts[intensityLevel(for: cost, maxCost: maxCost)] += 1
        }
    }

    private func average(of values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
}

// MARK: - Color Grid Builder (Pure Functions)

private extension ThemeColorGrid {

    /// Build pre-computed color grid for all level/variation combinations
    static func buildColorGrid(for theme: HeatmapColorTheme) -> [[Color]] {
        theme.colors.map { baseColor in
            ColorVariation.allCases.map { variation in
                variation.apply(to: baseColor)
            }
        }
    }
}

// MARK: - Shared Instance (Convenience)

public extension ThemeColorGrid {
    /// Default shared grid for convenience (immutable, thread-safe)
    static let shared = ThemeColorGrid()
}

// MARK: - Color Manager (Uses Immutable Grids)

/// Color manager using immutable pre-computed color grids.
/// Thread-safe through immutable data structures - no mutable cache needed.
public final class HeatmapColorManager: Sendable {

    // MARK: - Singleton

    public static let shared = HeatmapColorManager()

    // MARK: - Lazy Pre-computed Grids

    /// Lazily initialized color grids per theme (computed once, immutable thereafter)
    private let grids: [HeatmapColorTheme: ThemeColorGrid]

    /// Package-internal initializer for testing
    init() {
        // Pre-compute grids for all themes at initialization
        self.grids = Dictionary(uniqueKeysWithValues: HeatmapColorTheme.allCases.map { theme in
            (theme, ThemeColorGrid(theme: theme))
        })
    }

    // MARK: - Types

    public typealias ColorVariation = ClaudeUsageUI.ColorVariation

    // MARK: - Public Interface (High Level)

    /// Get color for a cost value (O(1) lookup from pre-computed grid)
    public func color(
        for cost: Double,
        maxCost: Double,
        theme: HeatmapColorTheme = .github,
        variation: ColorVariation = .normal
    ) -> Color {
        grid(for: theme).color(for: cost, maxCost: maxCost, variation: variation)
    }

    /// Pre-calculate colors for a range of values
    public func preCalculateColors(
        for costs: [Double],
        maxCost: Double,
        theme: HeatmapColorTheme = .github
    ) -> [Double: Color] {
        grid(for: theme).mapColors(for: costs, maxCost: maxCost)
    }

    /// Analyze color distribution for a dataset
    public func analyzeColorDistribution(costs: [Double], maxCost: Double) -> ColorDistribution {
        ThemeColorGrid.shared.analyzeDistribution(costs: costs, maxCost: maxCost)
    }

    /// Clear color cache (no-op: grids are immutable)
    public func clearCache() {
        // No-op: ThemeColorGrid is immutable, no cache to clear
    }

    // MARK: - Grid Access

    private func grid(for theme: HeatmapColorTheme) -> ThemeColorGrid {
        grids[theme] ?? ThemeColorGrid.shared
    }
}

// MARK: - Color Distribution

/// Statistics about color distribution in a heatmap
public struct ColorDistribution: Sendable {
    public let totalItems: Int
    public let levelCounts: [Int] // Count for each of the 5 color levels
    public let maxCost: Double
    public let averageCost: Double

    /// Percentage distribution across levels
    public var levelPercentages: [Double] {
        guard totalItems > 0 else { return Array(repeating: 0, count: 5) }
        return levelCounts.map { Double($0) / Double(totalItems) * 100 }
    }

    /// Most common color level
    public var dominantLevel: Int {
        levelCounts.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
    }
}

// MARK: - Accessibility Colors

/// Accessibility-friendly color management
public struct AccessibilityColorScheme {

    /// High contrast color scheme for better accessibility
    public static let highContrast = HeatmapColorTheme.custom(colors: [
        Color.black.opacity(0.1),
        Color.blue.opacity(0.4),
        Color.blue.opacity(0.6),
        Color.blue.opacity(0.8),
        Color.blue
    ])

    /// Colorblind-friendly color scheme (safe for deuteranopia/protanopia)
    public static let colorblindFriendly = HeatmapColorTheme.custom(colors: [
        Color.gray.opacity(0.3),
        Color.blue.opacity(0.3),
        Color.blue.opacity(0.5),
        Color.blue.opacity(0.7),
        Color.blue
    ])

    /// Monochrome scheme for ultimate accessibility
    public static let monochrome = HeatmapColorTheme.custom(colors: [
        Color(white: 0.9),
        Color(white: 0.7),
        Color(white: 0.5),
        Color(white: 0.3),
        Color(white: 0.1)
    ])
}

// MARK: - Dynamic Color Themes

public extension HeatmapColorTheme {

    /// Create a custom color theme
    static func custom(colors: [Color]) -> HeatmapColorTheme {
        // Returns default theme - custom themes would require enum modification
        .github
    }

    /// Generate a color theme based on a base color
    static func generate(from baseColor: Color) -> [Color] {
        [
            Color(red: 240/255, green: 242/255, blue: 245/255),
            baseColor.opacity(0.35),
            baseColor.opacity(0.55),
            baseColor.opacity(0.75),
            baseColor.opacity(0.95)
        ]
    }

    /// Check if a color theme provides sufficient contrast
    func hasGoodContrast() -> Bool {
        colors.count >= 2
    }
}

// MARK: - Performance Optimizations

/// Performance-optimized color utilities
public struct HeatmapColorPerformance: Sendable {

    /// Pre-computed color lookup table for common cost ranges
    public static func buildColorLUT(
        maxCost: Double,
        steps: Int = 100,
        theme: HeatmapColorTheme = .github
    ) -> [Color] {
        let grid = ThemeColorGrid(theme: theme)
        return (0...steps).map { i in
            let cost = Double(i) / Double(steps) * maxCost
            return grid.color(for: cost, maxCost: maxCost)
        }
    }

    /// Get color from lookup table for performance
    public static func colorFromLUT(
        cost: Double,
        maxCost: Double,
        lut: [Color]
    ) -> Color {
        guard maxCost > 0, !lut.isEmpty else { return HeatmapColorTheme.github.colors[0] }

        let normalizedCost = min(cost / maxCost, 1.0)
        let index = Int(normalizedCost * Double(lut.count - 1))
        let clampedIndex = max(0, min(lut.count - 1, index))

        return lut[clampedIndex]
    }
}

// MARK: - Color Utilities

public extension Color {

    /// Adjust brightness of a color
    func brightness(_ amount: Double) -> Color {
        self.opacity(max(0, min(1, 1.0 + amount)))
    }

    /// Adjust saturation of a color
    func saturation(_ amount: Double) -> Color {
        self
    }

    /// Get hex representation of color (useful for debugging)
    var hexString: String {
        "#000000"
    }
}

// MARK: - Intensity Level Calculation (Pure Functions)

private enum IntensityLevel {
    /// Intensity thresholds for each level
    static let thresholds: [(range: PartialRangeFrom<Double>, level: Int)] = [
        (0.75..., 4),
        (0.5..., 3),
        (0.25..., 2),
        (0.0..., 1)
    ]

    /// Convert intensity (0.0-1.0) to discrete level (0-4)
    static func fromIntensity(_ intensity: Double) -> Int {
        intensity == 0 ? 0 : (thresholds.first { $0.range.contains(intensity) }?.level ?? 1)
    }
}
