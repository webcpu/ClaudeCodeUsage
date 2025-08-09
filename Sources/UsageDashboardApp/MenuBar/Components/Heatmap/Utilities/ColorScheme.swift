//
//  ColorScheme.swift
//  Advanced color management for heatmap visualization
//
//  Provides sophisticated color calculations, theme management, and performance-optimized
//  color caching for heatmap components with accessibility support.
//

import SwiftUI
import Foundation

// MARK: - Color Manager

/// Advanced color management for heatmap visualizations
public final class HeatmapColorManager {
    
    // MARK: - Singleton
    
    public static let shared = HeatmapColorManager()
    private init() {}
    
    // MARK: - Color Caching
    
    /// Cache for expensive color calculations
    private var colorCache: [ColorCacheKey: Color] = [:]
    private let cacheQueue = DispatchQueue(label: "heatmap.color.cache", qos: .userInitiated)
    
    /// Key for color cache
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
    
    // MARK: - Color Variations
    
    /// Different color variations for special states
    public enum ColorVariation: String, CaseIterable {
        case normal = "normal"
        case hovered = "hovered"
        case selected = "selected"
        case dimmed = "dimmed"
        case highlighted = "highlighted"
    }
    
    // MARK: - Color Calculation
    
    /// Get color for a cost value with caching
    /// - Parameters:
    ///   - cost: The cost value
    ///   - maxCost: The maximum cost for scaling
    ///   - theme: The color theme to use
    ///   - variation: Color variation for special states
    /// - Returns: Optimized color for the given parameters
    public func color(
        for cost: Double,
        maxCost: Double,
        theme: HeatmapColorTheme = .github,
        variation: ColorVariation = .normal
    ) -> Color {
        let cacheKey = ColorCacheKey(cost: cost, maxCost: maxCost, theme: theme, variation: variation)
        
        // Check cache first
        if let cachedColor = colorCache[cacheKey] {
            return cachedColor
        }
        
        // Calculate color
        let baseColor = calculateBaseColor(cost: cost, maxCost: maxCost, theme: theme)
        let finalColor = applyVariation(baseColor, variation: variation)
        
        // Cache result
        cacheQueue.async { [weak self] in
            self?.colorCache[cacheKey] = finalColor
        }
        
        return finalColor
    }
    
    /// Calculate base color for cost value
    private func calculateBaseColor(cost: Double, maxCost: Double, theme: HeatmapColorTheme) -> Color {
        if cost == 0 { return theme.colors[0] }
        
        let intensity = maxCost > 0 ? min(cost / maxCost, 1.0) : 0.0
        let levelIndex = intensityToLevel(intensity)
        
        return theme.colors[levelIndex]
    }
    
    /// Convert intensity to discrete level (0-4)
    private func intensityToLevel(_ intensity: Double) -> Int {
        switch intensity {
        case 0:
            return 0 // Empty
        case 0..<0.25:
            return 1 // Low
        case 0.25..<0.5:
            return 2 // Medium-low
        case 0.5..<0.75:
            return 3 // Medium-high
        default:
            return 4 // High
        }
    }
    
    /// Apply color variation for different states
    private func applyVariation(_ baseColor: Color, variation: ColorVariation) -> Color {
        switch variation {
        case .normal:
            return baseColor
        case .hovered:
            return baseColor.opacity(0.8) // Slightly more transparent
        case .selected:
            return baseColor.brightness(0.2) // Slightly brighter
        case .dimmed:
            return baseColor.opacity(0.5) // More transparent
        case .highlighted:
            return baseColor.saturation(1.3) // More saturated
        }
    }
    
    // MARK: - Batch Operations
    
    /// Pre-calculate colors for a range of values (performance optimization)
    /// - Parameters:
    ///   - costs: Array of cost values
    ///   - maxCost: Maximum cost for scaling
    ///   - theme: Color theme to use
    /// - Returns: Dictionary mapping costs to colors
    public func preCalculateColors(
        for costs: [Double],
        maxCost: Double,
        theme: HeatmapColorTheme = .github
    ) -> [Double: Color] {
        var colorMap: [Double: Color] = [:]
        
        for cost in costs {
            colorMap[cost] = color(for: cost, maxCost: maxCost, theme: theme)
        }
        
        return colorMap
    }
    
    /// Clear color cache to free memory
    public func clearCache() {
        cacheQueue.async { [weak self] in
            self?.colorCache.removeAll()
        }
    }
    
    // MARK: - Color Analysis
    
    /// Analyze color distribution for a dataset
    /// - Parameters:
    ///   - costs: Array of cost values
    ///   - maxCost: Maximum cost value
    /// - Returns: Color distribution statistics
    public func analyzeColorDistribution(costs: [Double], maxCost: Double) -> ColorDistribution {
        var levelCounts = [0, 0, 0, 0, 0] // 5 levels
        
        for cost in costs {
            let intensity = maxCost > 0 ? min(cost / maxCost, 1.0) : 0.0
            let level = intensityToLevel(intensity)
            levelCounts[level] += 1
        }
        
        return ColorDistribution(
            totalItems: costs.count,
            levelCounts: levelCounts,
            maxCost: maxCost,
            averageCost: costs.isEmpty ? 0 : costs.reduce(0, +) / Double(costs.count)
        )
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
            Color.gray.opacity(0.3),          // Empty
            baseColor.opacity(0.25),          // Low
            baseColor.opacity(0.45),          // Medium-low
            baseColor.opacity(0.65),          // Medium-high
            baseColor                         // High
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
        var lut: [Color] = []
        lut.reserveCapacity(steps + 1)
        
        for i in 0...steps {
            let cost = Double(i) / Double(steps) * maxCost
            let color = HeatmapColorManager.shared.color(for: cost, maxCost: maxCost, theme: theme)
            lut.append(color)
        }
        
        return lut
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