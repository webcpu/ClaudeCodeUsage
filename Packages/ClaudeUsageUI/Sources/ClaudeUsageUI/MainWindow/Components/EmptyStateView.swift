//
//  EmptyStateView.swift
//  Reusable empty state component
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            iconView
            titleView
            messageView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    private var iconView: some View {
        Image(systemName: icon)
            .font(.system(size: 60))
            .foregroundColor(.secondary)
    }

    private var titleView: some View {
        Text(title)
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
    }

    private var messageView: some View {
        Text(message)
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 400)
    }
}