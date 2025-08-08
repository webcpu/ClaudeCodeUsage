//
//  ProgressBar.swift
//  Enhanced progress bar component with overflow support
//

import SwiftUI

@available(macOS 13.0, *)
struct ProgressBar: View {
    let value: Double // Can be > 1.0 for overflow
    let segments: [ProgressSegment]
    let showOverflow: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: MenuBarTheme.Layout.progressBarCornerRadius)
                    .fill(MenuBarTheme.Colors.UI.trackBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: MenuBarTheme.Layout.progressBarCornerRadius)
                            .stroke(MenuBarTheme.Colors.UI.trackBorder, lineWidth: MenuBarTheme.Graph.strokeWidth)
                    )
                
                // Progress fill
                HStack(spacing: 0) {
                    ForEach(segments.indices, id: \.self) { index in
                        let segment = segments[index]
                        let segmentValue = min(max(0, value - segment.range.lowerBound), 
                                              segment.range.upperBound - segment.range.lowerBound)
                        let segmentWidth = (segmentValue / (segment.range.upperBound - segment.range.lowerBound)) * 
                                         (segment.range.upperBound - segment.range.lowerBound) * geometry.size.width
                        
                        if segmentValue > 0 {
                            Rectangle()
                                .fill(LinearGradient(
                                    colors: [
                                        segment.color.opacity(MenuBarTheme.Graph.progressGradientStartOpacity),
                                        segment.color.opacity(MenuBarTheme.Graph.progressGradientEndOpacity)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(width: min(segmentWidth, geometry.size.width))
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: MenuBarTheme.Layout.progressBarCornerRadius))
                
                // Overflow indicator
                if showOverflow && value > 1.0 {
                    HStack {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(MenuBarTheme.Typography.overflowIcon)
                            .foregroundColor(MenuBarTheme.Colors.Status.critical)
                            .offset(x: 2)
                    }
                }
            }
        }
        .frame(height: MenuBarTheme.Layout.progressBarHeight)
    }
}