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
        HStack(spacing: GlanceTheme.Layout.itemSpacing) {
            Image(systemName: icon)
                .font(GlanceTheme.Typography.sectionIcon)
                .foregroundColor(color)
            
            Text(title.uppercased())
                .font(GlanceTheme.Typography.sectionTitle)
                .foregroundColor(GlanceTheme.Colors.UI.secondaryText)
                .kerning(GlanceTheme.Typography.sectionTitleKerning)
            
            if let badge = badge {
                badgeView(badge)
            }
            
            Spacer()
        }
        .padding(.horizontal, GlanceTheme.Layout.contentHorizontalPadding)
        .padding(.vertical, GlanceTheme.Layout.verticalPadding)
        .background(GlanceTheme.Colors.UI.sectionBackground)
    }
    
    // MARK: - Badge View
    private func badgeView(_ text: String) -> some View {
        Text(text)
            .font(GlanceTheme.Typography.badgeText)
            .foregroundColor(.white)
            .padding(.horizontal, GlanceTheme.Badge.horizontalPadding)
            .padding(.vertical, GlanceTheme.Badge.verticalPadding)
            .background(color)
            .cornerRadius(GlanceTheme.Badge.cornerRadius)
    }
}