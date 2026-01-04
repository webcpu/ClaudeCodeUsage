//
//  CaptureCompatibleScrollView.swift
//  ScrollView wrapper that skips ScrollView during ImageRenderer capture
//

import SwiftUI

// MARK: - Environment Key

private struct CaptureModeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isCaptureMode: Bool {
        get { self[CaptureModeKey.self] }
        set { self[CaptureModeKey.self] = newValue }
    }
}

// MARK: - Capture Compatible ScrollView

/// ScrollView that renders content directly (without scrolling) when in capture mode.
/// Use this instead of ScrollView for views that need ImageRenderer compatibility.
struct CaptureCompatibleScrollView<Content: View>: View {
    @Environment(\.isCaptureMode) private var isCaptureMode
    @ViewBuilder let content: Content

    var body: some View {
        if isCaptureMode {
            content
        } else {
            ScrollView { content }
        }
    }
}
