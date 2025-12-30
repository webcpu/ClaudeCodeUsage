//
//  HeatmapConfiguration+ColorThemes.swift
//
//  Color theme definitions for heatmap visualization.
//

import SwiftUI

// MARK: - Color Themes

/// Predefined color themes for heatmap visualization
public enum HeatmapColorTheme: String, CaseIterable, Equatable, @unchecked Sendable {
    case github = "github"
    case ocean = "ocean"
    case sunset = "sunset"
    case forest = "forest"
    case monochrome = "monochrome"

    /// Display name for the theme
    public var displayName: String {
        switch self {
        case .github: return "GitHub"
        case .ocean: return "Ocean"
        case .sunset: return "Sunset"
        case .forest: return "Forest"
        case .monochrome: return "Monochrome"
        }
    }

    /// Colors for this theme (light mode - legacy)
    public var colors: [Color] {
        colors(for: .light)
    }

    /// Colors for this theme based on color scheme
    public func colors(for scheme: ColorScheme) -> [Color] {
        switch self {
        case .github:
            return scheme == .dark ? githubDarkColors : githubLightColors
        case .ocean:
            return scheme == .dark ? oceanDarkColors : oceanLightColors
        case .sunset:
            return scheme == .dark ? sunsetDarkColors : sunsetLightColors
        case .forest:
            return scheme == .dark ? forestDarkColors : forestLightColors
        case .monochrome:
            return scheme == .dark ? monochromeDarkColors : monochromeLightColors
        }
    }

    /// Get color for specific intensity level (legacy - light mode)
    public func color(for level: Int) -> Color {
        color(for: level, scheme: .light)
    }

    /// Get color for specific intensity level and color scheme
    public func color(for level: Int, scheme: ColorScheme) -> Color {
        let themeColors = colors(for: scheme)
        let index = max(0, min(themeColors.count - 1, level))
        return themeColors[index]
    }

    // MARK: - GitHub Theme Colors

    private var githubLightColors: [Color] {
        [
            Color(red: 235/255, green: 237/255, blue: 240/255),  // Level 0: #ebedf0
            Color(red: 155/255, green: 233/255, blue: 168/255),  // Level 1: #9be9a8
            Color(red: 64/255, green: 196/255, blue: 99/255),    // Level 2: #40c463
            Color(red: 48/255, green: 161/255, blue: 78/255),    // Level 3: #30a14e
            Color(red: 33/255, green: 110/255, blue: 57/255)     // Level 4: #216e39
        ]
    }

    private var githubDarkColors: [Color] {
        [
            Color(red: 22/255, green: 27/255, blue: 34/255),     // Level 0: #161b22
            Color(red: 14/255, green: 68/255, blue: 41/255),     // Level 1: #0e4429
            Color(red: 0/255, green: 109/255, blue: 50/255),     // Level 2: #006d32
            Color(red: 38/255, green: 166/255, blue: 65/255),    // Level 3: #26a641
            Color(red: 57/255, green: 211/255, blue: 83/255)     // Level 4: #39d353
        ]
    }

    // MARK: - Ocean Theme Colors

    private var oceanLightColors: [Color] {
        [
            Color.gray.opacity(0.3),
            Color.blue.opacity(0.25),
            Color.blue.opacity(0.45),
            Color.blue.opacity(0.65),
            Color.blue
        ]
    }

    private var oceanDarkColors: [Color] {
        [
            Color(white: 0.15),
            Color.blue.opacity(0.35),
            Color.blue.opacity(0.55),
            Color.blue.opacity(0.75),
            Color(red: 0.3, green: 0.6, blue: 1.0)
        ]
    }

    // MARK: - Sunset Theme Colors

    private var sunsetLightColors: [Color] {
        [
            Color.gray.opacity(0.3),
            Color.yellow.opacity(0.4),
            Color.orange.opacity(0.6),
            Color.red.opacity(0.7),
            Color.red
        ]
    }

    private var sunsetDarkColors: [Color] {
        [
            Color(white: 0.15),
            Color.yellow.opacity(0.5),
            Color.orange.opacity(0.7),
            Color.red.opacity(0.8),
            Color(red: 1.0, green: 0.3, blue: 0.3)
        ]
    }

    // MARK: - Forest Theme Colors

    private var forestLightColors: [Color] {
        [
            Color.gray.opacity(0.3),
            Color.mint.opacity(0.3),
            Color.green.opacity(0.5),
            Color.green.opacity(0.7),
            Color(red: 0, green: 0.5, blue: 0)
        ]
    }

    private var forestDarkColors: [Color] {
        [
            Color(white: 0.15),
            Color.mint.opacity(0.4),
            Color.green.opacity(0.6),
            Color.green.opacity(0.8),
            Color(red: 0.2, green: 0.8, blue: 0.2)
        ]
    }

    // MARK: - Monochrome Theme Colors

    private var monochromeLightColors: [Color] {
        [
            Color.gray.opacity(0.3),
            Color.gray.opacity(0.5),
            Color.gray.opacity(0.7),
            Color.gray.opacity(0.85),
            Color.gray
        ]
    }

    private var monochromeDarkColors: [Color] {
        [
            Color(white: 0.15),
            Color(white: 0.35),
            Color(white: 0.5),
            Color(white: 0.65),
            Color(white: 0.8)
        ]
    }
}
