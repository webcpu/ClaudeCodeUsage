//
//  HeatmapConfiguration+ColorThemes.swift
//
//  Color theme definitions for heatmap visualization.
//

import SwiftUI

// MARK: - Theme Descriptor (OCP: Open for Extension)

/// Describes a color theme with its metadata and colors.
/// Add new themes by adding entries to the registry.
private struct ThemeDescriptor {
    let displayName: String
    let lightColors: [Color]
    let darkColors: [Color]
}

// MARK: - Theme Registry

/// Registry of all available themes.
/// Add new themes here - no switch statements required elsewhere.
private enum ThemeRegistry {
    static let themes: [HeatmapColorTheme: ThemeDescriptor] = [
        .github: ThemeDescriptor(
            displayName: "GitHub",
            lightColors: [
                Color(red: 235/255, green: 237/255, blue: 240/255),
                Color(red: 155/255, green: 233/255, blue: 168/255),
                Color(red: 64/255, green: 196/255, blue: 99/255),
                Color(red: 48/255, green: 161/255, blue: 78/255),
                Color(red: 33/255, green: 110/255, blue: 57/255)
            ],
            darkColors: [
                Color(red: 22/255, green: 27/255, blue: 34/255),
                Color(red: 14/255, green: 68/255, blue: 41/255),
                Color(red: 0/255, green: 109/255, blue: 50/255),
                Color(red: 38/255, green: 166/255, blue: 65/255),
                Color(red: 57/255, green: 211/255, blue: 83/255)
            ]
        ),
        .ocean: ThemeDescriptor(
            displayName: "Ocean",
            lightColors: [
                Color.gray.opacity(0.3),
                Color.blue.opacity(0.25),
                Color.blue.opacity(0.45),
                Color.blue.opacity(0.65),
                Color.blue
            ],
            darkColors: [
                Color(white: 0.15),
                Color.blue.opacity(0.35),
                Color.blue.opacity(0.55),
                Color.blue.opacity(0.75),
                Color(red: 0.3, green: 0.6, blue: 1.0)
            ]
        ),
        .sunset: ThemeDescriptor(
            displayName: "Sunset",
            lightColors: [
                Color.gray.opacity(0.3),
                Color.yellow.opacity(0.4),
                Color.orange.opacity(0.6),
                Color.red.opacity(0.7),
                Color.red
            ],
            darkColors: [
                Color(white: 0.15),
                Color.yellow.opacity(0.5),
                Color.orange.opacity(0.7),
                Color.red.opacity(0.8),
                Color(red: 1.0, green: 0.3, blue: 0.3)
            ]
        ),
        .forest: ThemeDescriptor(
            displayName: "Forest",
            lightColors: [
                Color.gray.opacity(0.3),
                Color.mint.opacity(0.3),
                Color.green.opacity(0.5),
                Color.green.opacity(0.7),
                Color(red: 0, green: 0.5, blue: 0)
            ],
            darkColors: [
                Color(white: 0.15),
                Color.mint.opacity(0.4),
                Color.green.opacity(0.6),
                Color.green.opacity(0.8),
                Color(red: 0.2, green: 0.8, blue: 0.2)
            ]
        ),
        .monochrome: ThemeDescriptor(
            displayName: "Monochrome",
            lightColors: [
                Color.gray.opacity(0.3),
                Color.gray.opacity(0.5),
                Color.gray.opacity(0.7),
                Color.gray.opacity(0.85),
                Color.gray
            ],
            darkColors: [
                Color(white: 0.15),
                Color(white: 0.35),
                Color(white: 0.5),
                Color(white: 0.65),
                Color(white: 0.8)
            ]
        )
    ]

    static func descriptor(for theme: HeatmapColorTheme) -> ThemeDescriptor {
        themes[theme] ?? themes[.github]!
    }
}

// MARK: - Color Themes

/// Predefined color themes for heatmap visualization
public enum HeatmapColorTheme: String, CaseIterable, Equatable, Hashable, @unchecked Sendable {
    case github = "github"
    case ocean = "ocean"
    case sunset = "sunset"
    case forest = "forest"
    case monochrome = "monochrome"

    /// Display name for the theme (from registry)
    public var displayName: String {
        ThemeRegistry.descriptor(for: self).displayName
    }

    /// Colors for this theme (light mode - legacy)
    public var colors: [Color] {
        colors(for: .light)
    }

    /// Colors for this theme based on color scheme (from registry)
    public func colors(for scheme: ColorScheme) -> [Color] {
        let descriptor = ThemeRegistry.descriptor(for: self)
        return scheme == .dark ? descriptor.darkColors : descriptor.lightColors
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
}
