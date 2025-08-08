//
//  MenuBarStyles.swift
//  Reusable button styles for the menu bar
//

import SwiftUI

// MARK: - Menu Button Style
@available(macOS 13.0, *)
struct MenuButtonStyle: ButtonStyle {
    enum Style {
        case primary, secondary
    }
    
    let style: Style
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MenuBarTheme.Typography.actionButton)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, MenuBarTheme.Button.horizontalPadding)
            .padding(.vertical, MenuBarTheme.Button.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: MenuBarTheme.Button.cornerRadius)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: MenuBarTheme.Button.cornerRadius)
                            .stroke(borderColor, lineWidth: MenuBarTheme.Button.borderWidth)
                    )
            )
            .scaleEffect(configuration.isPressed ? MenuBarTheme.Animation.scalePressed : MenuBarTheme.Animation.scaleNormal)
            .animation(MenuBarTheme.Animation.buttonPress, value: configuration.isPressed)
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary:
            return MenuBarTheme.Colors.UI.primaryButtonText
        case .secondary:
            return MenuBarTheme.Colors.UI.secondaryButtonText
        }
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return MenuBarTheme.Colors.UI.primaryButtonBackground
        case .secondary:
            return MenuBarTheme.Colors.UI.secondaryButtonBackground
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .primary:
            return MenuBarTheme.Colors.UI.primaryButtonBorder
        case .secondary:
            return MenuBarTheme.Colors.UI.secondaryButtonBorder
        }
    }
}