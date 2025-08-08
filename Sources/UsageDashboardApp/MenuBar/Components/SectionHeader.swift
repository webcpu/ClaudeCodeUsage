//
//  SectionHeader.swift
//  Section header component with icon and optional badge
//

import SwiftUI

@available(macOS 13.0, *)
struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color
    let badge: String?
    
    var body: some View {
        HStack(spacing: MenuBarTheme.Layout.itemSpacing) {
            Image(systemName: icon)
                .font(MenuBarTheme.Typography.sectionIcon)
                .foregroundColor(color)
            
            Text(title.uppercased())
                .font(MenuBarTheme.Typography.sectionTitle)
                .foregroundColor(MenuBarTheme.Colors.UI.secondaryText)
                .kerning(MenuBarTheme.Typography.sectionTitleKerning)
            
            if let badge = badge {
                badgeView(badge)
            }
            
            Spacer()
        }
        .padding(.horizontal, MenuBarTheme.Layout.horizontalPadding)
        .padding(.vertical, MenuBarTheme.Layout.verticalPadding)
        .background(MenuBarTheme.Colors.UI.sectionBackground)
    }
    
    // MARK: - Badge View
    private func badgeView(_ text: String) -> some View {
        Text(text)
            .font(MenuBarTheme.Typography.badgeText)
            .foregroundColor(.white)
            .padding(.horizontal, MenuBarTheme.Badge.horizontalPadding)
            .padding(.vertical, MenuBarTheme.Badge.verticalPadding)
            .background(color)
            .cornerRadius(MenuBarTheme.Badge.cornerRadius)
    }
}