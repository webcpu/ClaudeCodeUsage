//
//  OpenAtLoginToggle.swift
//  Menu bar toggle for Open at Login setting
//

import SwiftUI

public struct OpenAtLoginToggle: View {
    let settingsService: AppSettingsService
    @State private var isHovered = false

    public init(settingsService: AppSettingsService) {
        self.settingsService = settingsService
    }

    public var body: some View {
        HStack(spacing: Layout.spacing) {
            checkboxIcon
            labelText
            Spacer()
        }
        .padding(.vertical, Layout.verticalPadding)
        .padding(.horizontal, Layout.horizontalPadding)
        .background(hoverBackground)
        .onHover { isHovered = $0 }
        .onTapGesture(perform: toggleSetting)
        .help("Launch \(AppMetadata.name) automatically when you log in")
    }
}

// MARK: - Subviews

private extension OpenAtLoginToggle {
    var checkboxIcon: some View {
        Image(systemName: checkboxIconName)
            .foregroundColor(checkboxColor)
            .font(.system(size: Layout.iconSize))
            .animation(Layout.hoverAnimation, value: isEnabled)
            .animation(Layout.hoverAnimation, value: isHovered)
    }

    var labelText: some View {
        Text("Open at Login")
            .font(MenuBarTheme.Typography.actionButton)
            .foregroundColor(labelColor)
    }

    var hoverBackground: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius)
            .fill(isHovered ? Color.gray.opacity(Layout.hoverOpacity) : .clear)
    }
}

// MARK: - Computed State

private extension OpenAtLoginToggle {
    var isEnabled: Bool {
        settingsService.isOpenAtLoginEnabled
    }

    var checkboxIconName: String {
        isEnabled ? "checkmark.square.fill" : "square"
    }

    var checkboxColor: Color {
        isEnabled ? .accentColor : (isHovered ? .primary : .secondary)
    }

    var labelColor: Color {
        isHovered ? .primary : .secondary
    }
}

// MARK: - Actions

private extension OpenAtLoginToggle {
    func toggleSetting() {
        Task {
            _ = await settingsService.setOpenAtLogin(!isEnabled)
        }
    }
}

// MARK: - Layout Constants

private extension OpenAtLoginToggle {
    enum Layout {
        static let spacing: CGFloat = 8
        static let iconSize: CGFloat = 12
        static let verticalPadding: CGFloat = 6
        static let horizontalPadding: CGFloat = 8
        static let cornerRadius: CGFloat = 4
        static let hoverOpacity: Double = 0.1
        static let hoverAnimation = Animation.easeInOut(duration: 0.1)
    }
}
