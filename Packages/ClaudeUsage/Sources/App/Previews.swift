//
//  Previews.swift
//  Xcode previews
//

#if DEBUG

import SwiftUI

#Preview("MenuBar", traits: .appEnvironment) {
    MenuBarContentView()
        .frame(width: 360, height: 500)
}

#Preview("MainWindow", traits: .appEnvironment) {
    MainView()
        .frame(width: 1100, height: 700)
}

#Preview("MainWindow-Overview", traits: .appEnvironment) {
    MainView(initialDestination: .overview)
        .frame(width: 1100, height: 700)
}

#Preview("MainWindow-Models", traits: .appEnvironment) {
    MainView(initialDestination: .models)
        .frame(width: 1100, height: 700)
}

#Preview("MainWindow-DailyUsage", traits: .appEnvironment) {
    MainView(initialDestination: .dailyUsage)
        .frame(width: 1100, height: 700)
}

#Preview("MainWindow-Analytics", traits: .appEnvironment) {
    MainView(initialDestination: .analytics)
        .frame(width: 1100, height: 700)
}

#Preview("MainWindow-LiveMetrics", traits: .appEnvironment) {
    MainView(initialDestination: .liveMetrics)
        .frame(width: 1100, height: 700)
}

#endif
