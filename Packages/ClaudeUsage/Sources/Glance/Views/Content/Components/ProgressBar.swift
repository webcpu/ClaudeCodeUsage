//
//  ProgressBar.swift
//  Enhanced progress bar component with overflow support
//

import SwiftUI

@available(macOS 13.0, *)
struct ProgressBar: View {
    let value: Double
    let segments: [ProgressSegment]
    let showOverflow: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                backgroundTrack
                progressFill(width: geometry.size.width)
                overflowIndicator
            }
        }
        .frame(height: GlanceTheme.Layout.progressBarHeight)
    }

    // MARK: - View Components

    private var backgroundTrack: some View {
        RoundedRectangle(cornerRadius: GlanceTheme.Layout.progressBarCornerRadius)
            .fill(GlanceTheme.Colors.UI.trackBackground)
            .overlay(trackBorder)
    }

    private var trackBorder: some View {
        RoundedRectangle(cornerRadius: GlanceTheme.Layout.progressBarCornerRadius)
            .stroke(GlanceTheme.Colors.UI.trackBorder, lineWidth: GlanceTheme.Graph.strokeWidth)
    }

    private func progressFill(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(segments.indices, id: \.self) { index in
                segmentView(for: segments[index], containerWidth: width)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: GlanceTheme.Layout.progressBarCornerRadius))
    }

    @ViewBuilder
    private func segmentView(for segment: ProgressSegment, containerWidth: CGFloat) -> some View {
        let fillValue = segmentFillValue(for: segment)
        if fillValue > 0 {
            Rectangle()
                .fill(segmentGradient(for: segment))
                .frame(width: min(fillValue * containerWidth, containerWidth))
        }
    }

    @ViewBuilder
    private var overflowIndicator: some View {
        if shouldShowOverflowIndicator {
            HStack {
                Spacer()
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(GlanceTheme.Typography.overflowIcon)
                    .foregroundColor(GlanceTheme.Colors.Status.critical)
                    .offset(x: 2)
            }
        }
    }

    // MARK: - Pure Functions

    private var shouldShowOverflowIndicator: Bool {
        showOverflow && value > 1.0
    }

    private func segmentFillValue(for segment: ProgressSegment) -> Double {
        let rangeLength = segment.range.upperBound - segment.range.lowerBound
        let clampedValue = min(max(0, value - segment.range.lowerBound), rangeLength)
        return clampedValue
    }

    private func segmentGradient(for segment: ProgressSegment) -> LinearGradient {
        LinearGradient(
            colors: [
                segment.color.opacity(GlanceTheme.Graph.progressGradientStartOpacity),
                segment.color.opacity(GlanceTheme.Graph.progressGradientEndOpacity)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}