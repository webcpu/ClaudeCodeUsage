//
//  MenuBarStyles.swift
//  Reusable button styles for the menu bar
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
    static let styles: [MenuButtonStyle.Style: StyleDescriptor] = [
        .primary: StyleDescriptor(
            foregroundColor: MenuBarTheme.Colors.UI.primaryButtonText,
            backgroundColor: MenuBarTheme.Colors.UI.primaryButtonBackground,
            borderColor: MenuBarTheme.Colors.UI.primaryButtonBorder
        ),
        .secondary: StyleDescriptor(
            foregroundColor: MenuBarTheme.Colors.UI.secondaryButtonText,
            backgroundColor: MenuBarTheme.Colors.UI.secondaryButtonBackground,
            borderColor: MenuBarTheme.Colors.UI.secondaryButtonBorder
        )
    ]

    /// Retrieves the descriptor for a given style, with a sensible default fallback.
    static func descriptor(for style: MenuButtonStyle.Style) -> StyleDescriptor {
        styles[style] ?? styles[.primary]!
    }
}

// MARK: - Menu Button Style

@available(macOS 13.0, *)
struct MenuButtonStyle: ButtonStyle {
    enum Style {
        case primary, secondary
    }

    let style: Style

    private var descriptor: StyleDescriptor {
        StyleDescriptor.descriptor(for: style)
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MenuBarTheme.Typography.actionButton)
            .foregroundColor(descriptor.foregroundColor)
            .padding(.horizontal, MenuBarTheme.Button.horizontalPadding)
            .padding(.vertical, MenuBarTheme.Button.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: MenuBarTheme.Button.cornerRadius)
                    .fill(descriptor.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: MenuBarTheme.Button.cornerRadius)
                            .stroke(descriptor.borderColor, lineWidth: MenuBarTheme.Button.borderWidth)
                    )
            )
            .scaleEffect(configuration.isPressed ? MenuBarTheme.Animation.scalePressed : MenuBarTheme.Animation.scaleNormal)
            .animation(MenuBarTheme.Animation.buttonPress, value: configuration.isPressed)
    }
}