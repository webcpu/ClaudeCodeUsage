//
//  Previews.swift
//  Xcode previews
//

#if DEBUG

import SwiftUI

#Preview("Glance", traits: .appEnvironment) {
    GlanceView()
        .frame(width: 360, height: 500)
}

#Preview("Insights", traits: .appEnvironment) {
    InsightsView()
        .frame(width: 1100, height: 700)
}

#Preview("Insights-Overview", traits: .appEnvironment) {
    InsightsView(initialDestination: .overview)
        .frame(width: 1100, height: 700)
}

#Preview("Insights-Models", traits: .appEnvironment) {
    InsightsView(initialDestination: .models)
        .frame(width: 1100, height: 700)
}

#Preview("Insights-DailyUsage", traits: .appEnvironment) {
    InsightsView(initialDestination: .dailyUsage)
        .frame(width: 1100, height: 700)
}

#Preview("Insights-Analytics", traits: .appEnvironment) {
    InsightsView(initialDestination: .analytics)
        .frame(width: 1100, height: 700)
}

#Preview("Insights-LiveMetrics", traits: .appEnvironment) {
    InsightsView(initialDestination: .liveMetrics)
        .frame(width: 1100, height: 700)
}

#endif
