//
//  ContentStateRouter.swift
//  Reusable state routing abstraction for loading/loaded/error states
//

import SwiftUI

// MARK: - Routable Content State

/// Generic content state that can be used across all views.
/// Renamed to avoid collision with private ContentState enums in individual views.
enum RoutableState<Data> {
    case loading
    case empty
    case loaded(Data)
    case error
}

// MARK: - Content State Protocol

/// Protocol for content states that can be routed to appropriate views.
/// Implementations provide the loading message and error display configuration.
protocol ContentStateRouting {
    associatedtype LoadedData
    associatedtype LoadedView: View

    /// Message shown during loading state
    var loadingMessage: String { get }

    /// Configuration for the empty/error state display
    var errorDisplay: ErrorDisplay { get }

    /// Creates the view for loaded state
    @ViewBuilder func loadedView(for data: LoadedData) -> LoadedView
}

/// Configuration for error state display
struct ErrorDisplay {
    let icon: String
    let title: String
    let message: String
}

// MARK: - State Router View

/// Generic view that routes content state to appropriate views
struct ContentStateRouterView<Router: ContentStateRouting, Data>: View where Router.LoadedData == Data {
    let state: RoutableState<Data>
    let router: Router

    var body: some View {
        switch state {
        case .loading:
            ContentLoadingView(message: router.loadingMessage)
        case .empty:
            EmptyStateView(
                icon: router.errorDisplay.icon,
                title: router.errorDisplay.title,
                message: router.errorDisplay.message
            )
        case .loaded(let data):
            router.loadedView(for: data)
        case .error:
            EmptyStateView(
                icon: router.errorDisplay.icon,
                title: router.errorDisplay.title,
                message: router.errorDisplay.message
            )
        }
    }
}

// MARK: - Loading View

/// Shared loading view for all content state routers
struct ContentLoadingView: View {
    let message: String

    var body: some View {
        ProgressView(message)
            .frame(maxWidth: .infinity)
            .padding(.top, 50)
    }
}
