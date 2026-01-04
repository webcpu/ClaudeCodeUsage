//
//  AppEnvironment+Preview.swift
//  Preview support for SwiftUI previews
//

import SwiftUI

#if DEBUG

func timestamp() -> String {
    let now = Date()
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    return formatter.string(from: now)
}

public struct PreviewEnvironment: PreviewModifier {
    public static func makeSharedContext() async throws -> AppEnvironment {
        print("\(timestamp()) PreviewEnvironment: Making shared context")
        let env = AppEnvironment.live()
        print("\(timestamp()) PreviewEnvironment: glanceStore.loadData start")
        await env.glanceStore.loadData()
        print("\(timestamp()) PreviewEnvironment: glanceStore.loadData end")
        print("\(timestamp()) PreviewEnvironment: insightsStore.loadData start")
        await env.insightsStore.loadData()
        print("\(timestamp()) PreviewEnvironment: insightsStore.loadData end")
        return env
    }

    public func body(content: Content, context: AppEnvironment) -> some View {
        content
            .environment(context.glanceStore)
            .environment(context.insightsStore)
            .environment(context.settings)
    }
}

public extension PreviewTrait where T == Preview.ViewTraits {
    static var appEnvironment: PreviewTrait<T> {
        .modifier(PreviewEnvironment())
    }
}
#endif
