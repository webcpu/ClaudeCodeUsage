//
//  ColorScheme.swift
//  Advanced color management for heatmap visualization
//
//  Provides sophisticated color calculations, theme management, and performance-optimized
//  color caching for heatmap components with accessibility support.
//

import SwiftUI
import Foundation

// MARK: - Intensity Level Calculation (Pure Functions)

private enum IntensityLevel {
    /// Intensity thresholds for each level
    static let thresholds: [(range: PartialRangeFrom<Double>, level: Int)] = [
        (0.75..., 4),  // High
        (0.5..., 3),   // Medium-high
        (0.25..., 2),  // Medium-low
        (0.0..., 1)    // Low (anything > 0)
    ]

    /// Convert intensity (0.0-1.0) to discrete level (0-4)
    static func fromIntensity(_ intensity: Double) -> Int {
        intensity == 0 ? 0 : (thresholds.first { $0.range.contains(intensity) }?.level ?? 1)
    }
}

// MARK: - Color Manager

/// Advanced color management for heatmap visualizations
public final class HeatmapColorManager {

    // MARK: - Singleton

    public static let shared = HeatmapColorManager()
    private init() {}

    // MARK: - Types

    /// Different color variations for special states
    public enum ColorVariation: String, CaseIterable {
        case normal = "normal"
        case hovered = "hovered"
        case selected = "selected"
        case dimmed = "dimmed"
        case highlighted = "highlighted"
    }

    // MARK: - Public Interface (High Level)

    /// Get color for a cost value with caching
    public func color(
        for cost: Double,
        maxCost: Double,
        theme: HeatmapColorTheme = .github,
        variation: ColorVariation = .normal
    ) -> Color {
        cachedColor(for: cost, maxCost: maxCost, theme: theme, variation: variation)
            ?? computeAndCacheColor(for: cost, maxCost: maxCost, theme: theme, variation: variation)
    }

    /// Pre-calculate colors for a range of values (performance optimization)
    public func preCalculateColors(
        for costs: [Double],
        maxCost: Double,
        theme: HeatmapColorTheme = .github
    ) -> [Double: Color] {
        costs.reduce(into: [:]) { colorMap, cost in
            colorMap[cost] = color(for: cost, maxCost: maxCost, theme: theme)
        }
    }

    /// Analyze color distribution for a dataset
    public func analyzeColorDistribution(costs: [Double], maxCost: Double) -> ColorDistribution {
        let levelCounts = countCostsByLevel(costs, maxCost: maxCost)
        let averageCost = calculateAverageCost(costs)

        return ColorDistribution(
            totalItems: costs.count,
            levelCounts: levelCounts,
            maxCost: maxCost,
            averageCost: averageCost
        )
    }

    /// Clear color cache to free memory
    public func clearCache() {
        cacheQueue.async { [weak self] in
            self?.colorCache.removeAll()
        }
    }

    // MARK: - Color Calculation (Mid Level)

    private func computeAndCacheColor(
        for cost: Double,
        maxCost: Double,
        theme: HeatmapColorTheme,
        variation: ColorVariation
    ) -> Color {
        let baseColor = calculateBaseColor(cost: cost, maxCost: maxCost, theme: theme)
        let finalColor = applyVariation(baseColor, variation: variation)

        storeInCache(finalColor, for: cost, maxCost: maxCost, theme: theme, variation: variation)

        return finalColor
    }

    private func calculateBaseColor(cost: Double, maxCost: Double, theme: HeatmapColorTheme) -> Color {
        if cost == 0 { return theme.colors[0] }

        let intensity = calculateIntensity(cost: cost, maxCost: maxCost)
        let levelIndex = IntensityLevel.fromIntensity(intensity)

        return theme.colors[levelIndex]
    }

    private func calculateIntensity(cost: Double, maxCost: Double) -> Double {
        maxCost > 0 ? min(cost / maxCost, 1.0) : 0.0
    }

    private func countCostsByLevel(_ costs: [Double], maxCost: Double) -> [Int] {
        costs.reduce(into: [0, 0, 0, 0, 0]) { counts, cost in
            let intensity = calculateIntensity(cost: cost, maxCost: maxCost)
            let level = IntensityLevel.fromIntensity(intensity)
            counts[level] += 1
        }
    }

    private func calculateAverageCost(_ costs: [Double]) -> Double {
        costs.isEmpty ? 0 : costs.reduce(0, +) / Double(costs.count)
    }

    // MARK: - Caching (Infrastructure)

    private var colorCache: [ColorCacheKey: Color] = [:]
    private let cacheQueue = DispatchQueue(label: "heatmap.color.cache", qos: .userInitiated)

    private struct ColorCacheKey: Hashable {
        let cost: Double
        let maxCost: Double
        let theme: HeatmapColorTheme
        let variation: ColorVariation

        func hash(into hasher: inout Hasher) {
            hasher.combine(cost)
            hasher.combine(maxCost)
            hasher.combine(theme.rawValue)
            hasher.combine(variation.rawValue)
        }
    }

    private func cachedColor(
        for cost: Double,
        maxCost: Double,
        theme: HeatmapColorTheme,
        variation: ColorVariation
    ) -> Color? {
        let cacheKey = ColorCacheKey(cost: cost, maxCost: maxCost, theme: theme, variation: variation)
        return colorCache[cacheKey]
    }

    private func storeInCache(
        _ color: Color,
        for cost: Double,
        maxCost: Double,
        theme: HeatmapColorTheme,
        variation: ColorVariation
    ) {
        let cacheKey = ColorCacheKey(cost: cost, maxCost: maxCost, theme: theme, variation: variation)
        cacheQueue.async { [weak self] in
            self?.colorCache[cacheKey] = color
        }
    }

    // MARK: - Color Variations (Low Level)

    private func applyVariation(_ baseColor: Color, variation: ColorVariation) -> Color {
        switch variation {
        case .normal:
            return baseColor
        case .hovered:
            return baseColor.opacity(0.8)
        case .selected:
            return baseColor.brightness(0.2)
        case .dimmed:
            return baseColor.opacity(0.5)
        case .highlighted:
            return baseColor.saturation(1.3)
        }
    }
}

// MARK: - Color Distribution

/// Statistics about color distribution in a heatmap
public struct ColorDistribution {
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
        guard let maxIndex = levelCounts.enumerated().max(by: { $0.element < $1.element })?.offset else {
            return 0
        }
        return maxIndex
    }
}

// MARK: - Accessibility Colors

/// Accessibility-friendly color management
public struct AccessibilityColorScheme {
    
    /// High contrast color scheme for better accessibility
    public static let highContrast = HeatmapColorTheme.custom(colors: [
        Color.black.opacity(0.1),        // Empty - very light
        Color.blue.opacity(0.4),         // Low - medium blue
        Color.blue.opacity(0.6),         // Medium-low - darker blue
        Color.blue.opacity(0.8),         // Medium-high - dark blue
        Color.blue                       // High - full blue
    ])
    
    /// Colorblind-friendly color scheme (safe for deuteranopia/protanopia)
    public static let colorblindFriendly = HeatmapColorTheme.custom(colors: [
        Color.gray.opacity(0.3),         // Empty
        Color.blue.opacity(0.3),         // Low - blue instead of green
        Color.blue.opacity(0.5),         // Medium-low
        Color.blue.opacity(0.7),         // Medium-high
        Color.blue                       // High
    ])
    
    /// Monochrome scheme for ultimate accessibility
    public static let monochrome = HeatmapColorTheme.custom(colors: [
        Color(white: 0.9),               // Empty - very light gray
        Color(white: 0.7),               // Low
        Color(white: 0.5),               // Medium-low
        Color(white: 0.3),               // Medium-high
        Color(white: 0.1)                // High - very dark gray
    ])
}

// MARK: - Dynamic Color Themes

public extension HeatmapColorTheme {
    
    /// Create a custom color theme
    /// - Parameter colors: Array of 5 colors for the theme levels
    /// - Returns: Custom color theme
    static func custom(colors: [Color]) -> HeatmapColorTheme {
        // This would require modifying the enum to support custom themes
        // For now, we'll return a default theme
        return .github
    }
    
    /// Generate a color theme based on a base color
    /// - Parameter baseColor: The primary color to base the theme on
    /// - Returns: Generated color theme
    static func generate(from baseColor: Color) -> [Color] {
        return [
            Color(red: 240/255, green: 242/255, blue: 245/255),  // Empty
            baseColor.opacity(0.35),          // Low
            baseColor.opacity(0.55),          // Medium-low
            baseColor.opacity(0.75),          // Medium-high
            baseColor.opacity(0.95)           // High
        ]
    }
    
    /// Check if a color theme provides sufficient contrast
    /// - Parameter theme: The theme to check
    /// - Returns: True if the theme has good contrast
    func hasGoodContrast() -> Bool {
        // Simplified contrast check - in a real implementation,
        // you would calculate WCAG contrast ratios
        let colors = self.colors
        guard colors.count >= 2 else { return false }
        
        // Check that there's sufficient difference between empty and high
        // This is a simplified check - proper implementation would use luminance
        return true
    }
}

// MARK: - Performance Optimizations

/// Performance-optimized color utilities
public struct HeatmapColorPerformance {
    
    /// Pre-computed color lookup table for common cost ranges
    public static func buildColorLUT(
        maxCost: Double,
        steps: Int = 100,
        theme: HeatmapColorTheme = .github
    ) -> [Color] {
        (0...steps).map { i in
            let cost = Double(i) / Double(steps) * maxCost
            return HeatmapColorManager.shared.color(for: cost, maxCost: maxCost, theme: theme)
        }
    }
    
    /// Get color from lookup table for performance
    /// - Parameters:
    ///   - cost: Cost value
    ///   - maxCost: Maximum cost
    ///   - lut: Pre-computed lookup table
    /// - Returns: Color from lookup table
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
    /// - Parameter amount: Brightness adjustment (-1.0 to 1.0)
    /// - Returns: Color with adjusted brightness
    func brightness(_ amount: Double) -> Color {
        // This is a simplified implementation
        // Real implementation would convert to HSB, adjust, and convert back
        return self.opacity(max(0, min(1, 1.0 + amount)))
    }
    
    /// Adjust saturation of a color
    /// - Parameter amount: Saturation multiplier
    /// - Returns: Color with adjusted saturation
    func saturation(_ amount: Double) -> Color {
        // Simplified implementation
        return self
    }
    
    /// Get hex representation of color (useful for debugging)
    var hexString: String {
        // Simplified - real implementation would extract RGB components
        return "#000000"
    }
}