//
//  Previews.swift
//  Xcode previews
//

#if DEBUG

import SwiftUI

#Preview("Glance", traits: .appEnvironment) {
    GlanceView()
        .frame(width: 360, height: 500)
        .onAppear {
            print("\(timestamp()) Glance Preview Appeared")
        }
}

#Preview("Insights", traits: .appEnvironment) {
    InsightsView()
        .frame(width: 1100, height: 700)
}

#Preview("Insights-Overview", traits: .appEnvironment) {
    InsightsView(initialDestination: .overview)
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


#Preview("Insights-All-In-One", traits: .appEnvironment) {
    VStack(spacing: 20) {
        InsightsView(initialDestination: .overview)
            .frame(width: 1100, height: 700)

        InsightsView(initialDestination: .dailyUsage)
            .frame(width: 1100, height: 700)

        InsightsView(initialDestination: .analytics)
            .frame(width: 1100, height: 700)
   }
    .frame(width: 1100, height: 700*3)
    .scrollDisabled(true)
}
#endif
