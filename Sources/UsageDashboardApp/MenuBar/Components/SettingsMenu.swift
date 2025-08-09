//
//  SettingsMenu.swift
//  Reusable settings menu component with proper separation of concerns
//

import SwiftUI

struct SettingsMenu<Label: View>: View {
    @ObservedObject var settingsService: AppSettingsService
    @State private var showingError = false
    @State private var lastError: AppSettingsError?
    
    let label: () -> Label
    
    init(
        settingsService: AppSettingsService,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.settingsService = settingsService
        self.label = label
    }
    
    var body: some View {
        Menu {
            // Open at Login Toggle
            Toggle("Open at Login", isOn: openAtLoginBinding)
            
            Divider()
            
            // About
            Button("About \(settingsService.appName)") {
                settingsService.showAboutPanel()
            }
        } label: {
            label()
        }
        .alert(
            "Settings Error",
            isPresented: $showingError,
            presenting: lastError
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { error in
            Text(error.localizedDescription)
            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
            }
        }
    }
    
    private var openAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settingsService.isOpenAtLoginEnabled },
            set: { newValue in
                Task {
                    let result = await settingsService.setOpenAtLogin(newValue)
                    if case .failure(let error) = result {
                        lastError = error
                        showingError = true
                    }
                }
            }
        )
    }
}

// MARK: - Convenience Initializers

extension SettingsMenu {
    /// Creates a settings menu with a gear icon
    init(settingsService: AppSettingsService) where Label == Image {
        self.init(settingsService: settingsService) {
            Image(systemName: "gearshape.fill")
        }
    }
}

extension SettingsMenu where Label == Text {
    /// Creates a settings menu with text label
    init(_ title: String, settingsService: AppSettingsService) {
        self.init(settingsService: settingsService) {
            Text(title)
        }
    }
}