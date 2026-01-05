//
//  GlanceLabel.swift
//  Menu bar label showing today's cost
//

import SwiftUI

// MARK: - Glance Label

struct GlanceLabel: View {
    @Bindable var store: GlanceStore

    var body: some View {
        HStack(spacing: 4) {
            iconView
            costText
        }
    }

    private var iconView: some View {
        Image(systemName: appearance.icon)
            .foregroundColor(appearance.color)
    }

    private var costText: some View {
        Text(store.formattedTodaysCost)
            .font(.system(.body, design: .monospaced))
    }

    private var appearance: GlanceAppearanceConfig {
        GlanceAppearanceRegistry.select(from: store)
    }
}

// MARK: - Preview

#if DEBUG
private struct GlanceLabelPreview: View {
    @Environment(GlanceStore.self) private var store

    var body: some View {
        GlanceLabel(store: store)
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            .cornerRadius(8)
            .frame(width: 200, height: 100)
    }
}

#Preview("Glance Label", traits: .appEnvironment) {
    GlanceLabelPreview()
}
#endif
