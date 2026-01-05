//
//  GlanceStyles.swift
//  Reusable button styles for glance views
//

import SwiftUI

// MARK: - Style Descriptor (OCP Pattern)

/// Consolidates all style properties into a single descriptor,
/// eliminating multiple switch statements and enabling extension without modification.
struct StyleDescriptor {
    let foregroundColor: Color
    let backgroundColor: Color
    let borderColor: Color
}

// MARK: - Style Registry

extension StyleDescriptor {
    /// Registry mapping each style to its descriptor.
    /// To add a new style, simply add an entry here - no switch modifications needed.
    static let styles: [GlanceButtonStyle.Style: StyleDescriptor] = [
        .primary: StyleDescriptor(
            foregroundColor: GlanceTheme.Colors.UI.primaryButtonText,
            backgroundColor: GlanceTheme.Colors.UI.primaryButtonBackground,
            borderColor: GlanceTheme.Colors.UI.primaryButtonBorder
        ),
        .secondary: StyleDescriptor(
            foregroundColor: GlanceTheme.Colors.UI.secondaryButtonText,
            backgroundColor: GlanceTheme.Colors.UI.secondaryButtonBackground,
            borderColor: GlanceTheme.Colors.UI.secondaryButtonBorder
        )
    ]

    /// Retrieves the descriptor for a given style, with a sensible default fallback.
    static func descriptor(for style: GlanceButtonStyle.Style) -> StyleDescriptor {
        styles[style] ?? styles[.primary]!
    }
}

// MARK: - Menu Button Style

@available(macOS 13.0, *)
struct GlanceButtonStyle: ButtonStyle {
    enum Style {
        case primary, secondary
    }

    let style: Style

    private var descriptor: StyleDescriptor {
        StyleDescriptor.descriptor(for: style)
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(GlanceTheme.Typography.actionButton)
            .foregroundColor(descriptor.foregroundColor)
            .padding(.horizontal, GlanceTheme.Button.horizontalPadding)
            .padding(.vertical, GlanceTheme.Button.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: GlanceTheme.Button.cornerRadius)
                    .fill(descriptor.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: GlanceTheme.Button.cornerRadius)
                            .stroke(descriptor.borderColor, lineWidth: GlanceTheme.Button.borderWidth)
                    )
            )
            .scaleEffect(configuration.isPressed ? GlanceTheme.Animation.scalePressed : GlanceTheme.Animation.scaleNormal)
            .animation(GlanceTheme.Animation.buttonPress, value: configuration.isPressed)
    }
}