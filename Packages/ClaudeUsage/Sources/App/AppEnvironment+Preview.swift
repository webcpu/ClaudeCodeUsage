//
//  AppEnvironment+Preview.swift
//  Preview support for SwiftUI previews
//

import SwiftUI

#if DEBUG
public struct PreviewEnvironment: PreviewModifier {
    public static func makeSharedContext() async throws -> AppEnvironment {
        let env = AppEnvironment.live()
        await env.store.loadData()
        return env
    }

    public func body(content: Content, context: AppEnvironment) -> some View {
        content
            .environment(context.store)
            .environment(context.settings)
    }
}

public extension PreviewTrait where T == Preview.ViewTraits {
    static var appEnvironment: PreviewTrait<T> {
        .modifier(PreviewEnvironment())
    }
}
#endif
