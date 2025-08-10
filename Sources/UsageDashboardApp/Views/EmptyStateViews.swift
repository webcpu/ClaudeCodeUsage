//
//  EmptyStateViews.swift
//  Modern SwiftUI ContentUnavailableView implementations
//

import SwiftUI
import ClaudeCodeUsage

// MARK: - Empty State Views

/// Empty state for no usage data
struct NoUsageDataView: View {
    let onRefresh: () async -> Void
    @State private var isRefreshing = false
    
    var body: some View {
        ContentUnavailableView {
            Label("No Usage Data", systemImage: "chart.bar.xaxis")
        } description: {
            Text("Start using Claude to see your usage statistics")
        } actions: {
            Button(action: {
                Task {
                    isRefreshing = true
                    await onRefresh()
                    isRefreshing = false
                }
            }) {
                if isRefreshing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else {
                    Text("Refresh")
                }
            }
            .disabled(isRefreshing)
        }
    }
}

/// Empty state for no active session
struct NoActiveSessionView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Active Session", systemImage: "clock.badge.xmark")
        } description: {
            Text("No Claude session is currently active")
        }
    }
}

/// Empty state for chart with no data
struct NoChartDataView: View {
    let dateRange: String
    let onRefresh: () async -> Void
    @State private var isRefreshing = false
    
    var body: some View {
        ContentUnavailableView {
            Label("No Data Available", systemImage: "chart.line.downtrend.xyaxis")
        } description: {
            Text("No usage data found for \(dateRange)")
        } actions: {
            Button(action: {
                Task {
                    isRefreshing = true
                    await onRefresh()
                    isRefreshing = false
                }
            }) {
                if isRefreshing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else {
                    Text("Try Different Range")
                }
            }
            .disabled(isRefreshing)
        }
    }
}

/// Empty state for search results
struct NoSearchResultsView: View {
    let searchQuery: String
    let onClear: () -> Void
    
    var body: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
        } description: {
            Text("No results found for '\(searchQuery)'")
        } actions: {
            Button("Clear Search", action: onClear)
        }
    }
}

/// Empty state for projects list
struct NoProjectsView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Projects Yet", systemImage: "folder.badge.questionmark")
        } description: {
            Text("Projects will appear here as you use Claude in different directories")
        }
    }
}

// MARK: - Error State Views

/// Error state with retry action
struct ErrorStateView: View {
    let error: any Error
    let onRetry: () async -> Void
    @State private var isRetrying = false
    
    var body: some View {
        ContentUnavailableView {
            Label("Something Went Wrong", systemImage: "exclamationmark.triangle")
        } description: {
            Text(errorDescription)
                .multilineTextAlignment(.center)
            
            if let suggestion = recoverySuggestion {
                Text(suggestion)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        } actions: {
            Button(action: {
                Task {
                    isRetrying = true
                    await onRetry()
                    isRetrying = false
                }
            }) {
                if isRetrying {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else {
                    Text("Try Again")
                }
            }
            .disabled(isRetrying)
        }
    }
    
    private var errorDescription: String {
        if let claudeError = error as? ClaudeUsageError {
            return claudeError.errorDescription
        }
        return error.localizedDescription
    }
    
    private var recoverySuggestion: String? {
        if let claudeError = error as? ClaudeUsageError {
            return claudeError.recoverySuggestion
        }
        return nil
    }
}

/// Network error state
struct NetworkErrorView: View {
    let onRetry: () async -> Void
    @State private var isRetrying = false
    
    var body: some View {
        ContentUnavailableView {
            Label("No Internet Connection", systemImage: "wifi.slash")
        } description: {
            Text("Check your internet connection and try again")
        } actions: {
            Button(action: {
                Task {
                    isRetrying = true
                    await onRetry()
                    isRetrying = false
                }
            }) {
                if isRetrying {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else {
                    Text("Retry")
                }
            }
            .disabled(isRetrying)
        }
    }
}

// MARK: - Loading State Views

/// Loading state with message
struct LoadingStateView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply empty state overlay based on condition
    func emptyState<Content: View>(
        when condition: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        overlay {
            if condition {
                content()
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
    }
    
    /// Apply loading state overlay
    func loadingOverlay(
        isLoading: Bool,
        message: String = "Loading..."
    ) -> some View {
        overlay {
            if isLoading {
                LoadingStateView(message: message)
                    .background(Color.primary.opacity(0.05))
                    .transition(.opacity)
            }
        }
    }
    
    /// Apply error state overlay
    func errorOverlay(
        error: (any Error)?,
        onRetry: @escaping () async -> Void
    ) -> some View {
        overlay {
            if let error = error {
                ErrorStateView(error: error, onRetry: onRetry)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
}

// MARK: - Conditional Content View

/// View that shows content or empty state based on data availability
struct ConditionalContentView<Data, Content: View, Empty: View>: View {
    let data: Data?
    let content: (Data) -> Content
    let empty: () -> Empty
    
    init(
        data: Data?,
        @ViewBuilder content: @escaping (Data) -> Content,
        @ViewBuilder empty: @escaping () -> Empty
    ) {
        self.data = data
        self.content = content
        self.empty = empty
    }
    
    var body: some View {
        if let data = data {
            content(data)
        } else {
            empty()
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct EmptyStateViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NoUsageDataView(onRefresh: { })
                .previewDisplayName("No Usage Data")
            
            NoActiveSessionView()
                .previewDisplayName("No Active Session")
            
            NoChartDataView(
                dateRange: "Last 7 Days",
                onRefresh: { }
            )
            .previewDisplayName("No Chart Data")
            
            NoSearchResultsView(
                searchQuery: "test query",
                onClear: { }
            )
            .previewDisplayName("No Search Results")
            
            ErrorStateView(
                error: DataLoadingError.fileNotFound(path: "/test/path"),
                onRetry: { }
            )
            .previewDisplayName("Error State")
            
            NetworkErrorView(onRetry: { })
                .previewDisplayName("Network Error")
            
            LoadingStateView(message: "Loading your data...")
                .previewDisplayName("Loading State")
        }
        .frame(width: 400, height: 300)
    }
}
#endif