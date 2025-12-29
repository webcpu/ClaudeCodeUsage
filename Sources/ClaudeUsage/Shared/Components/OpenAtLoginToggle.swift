//
//  OpenAtLoginToggle.swift
//  Menu bar toggle for Open at Login setting
//

import SwiftUI

struct OpenAtLoginToggle: View {
    let settingsService: AppSettingsService
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: settingsService.isOpenAtLoginEnabled ? "checkmark.square.fill" : "square")
                .foregroundColor(settingsService.isOpenAtLoginEnabled ? .accentColor : isHovered ? .primary : .secondary)
                .font(.system(size: 12))
                .animation(.easeInOut(duration: 0.1), value: settingsService.isOpenAtLoginEnabled)
                .animation(.easeInOut(duration: 0.1), value: isHovered)
            
            Text("Open at Login")
                .font(MenuBarTheme.Typography.actionButton)
                .foregroundColor(isHovered ? .primary : .secondary)
            
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            Task {
                _ = await settingsService.setOpenAtLogin(!settingsService.isOpenAtLoginEnabled)
            }
        }
        .help("Launch \(AppMetadata.name) automatically when you log in")
    }
}