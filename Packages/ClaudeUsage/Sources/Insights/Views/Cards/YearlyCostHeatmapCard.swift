//
//  YearlyCostHeatmapCard.swift
//  Yearly cost heatmap visualization
//

import SwiftUI

struct YearlyCostHeatmapCard: View {
    let stats: UsageStats

    var body: some View {
        YearlyCostHeatmap(stats: stats)
    }
}
