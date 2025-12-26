//
//  TooltipConfiguration.swift
//  Configuration struct for tooltip appearance and behavior
//

import SwiftUI

// MARK: - Tooltip Configuration

/// Configuration for tooltip appearance and behavior
public struct TooltipConfiguration {

    /// Background material
    public let backgroundMaterial: Material

    /// Corner radius
    public let cornerRadius: CGFloat

    /// Shadow properties
    public let shadowColor: Color
    public let shadowRadius: CGFloat
    public let shadowOffset: CGSize

    /// Opacity
    public let opacity: Double

    /// Scale
    public let scale: CGFloat

    /// Animation
    public let animation: Animation?

    /// Default configuration
    public static let `default` = TooltipConfiguration(
        backgroundMaterial: .regularMaterial,
        cornerRadius: 8,
        shadowColor: .black.opacity(0.15),
        shadowRadius: 6,
        shadowOffset: CGSize(width: 0, height: 2),
        opacity: 1.0,
        scale: 1.0,
        animation: .easeInOut(duration: 0.2)
    )

    /// Minimal configuration without shadows or animations
    public static let minimal = TooltipConfiguration(
        backgroundMaterial: .thinMaterial,
        cornerRadius: 4,
        shadowColor: .clear,
        shadowRadius: 0,
        shadowOffset: .zero,
        opacity: 0.95,
        scale: 1.0,
        animation: nil
    )

    /// Enhanced configuration with prominent styling
    public static let enhanced = TooltipConfiguration(
        backgroundMaterial: .thickMaterial,
        cornerRadius: 12,
        shadowColor: .black.opacity(0.25),
        shadowRadius: 10,
        shadowOffset: CGSize(width: 0, height: 4),
        opacity: 1.0,
        scale: 1.05,
        animation: .spring(response: 0.4, dampingFraction: 0.8)
    )
}
