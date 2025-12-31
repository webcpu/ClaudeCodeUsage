//
//  SettingsMenu.swift
//  Reusable settings menu component
//

import SwiftUI

struct SettingsMenu<Label: View>: View {
    @Environment(AppSettingsService.self) private var settings
    @State private var showingError = false
    @State private var lastError: AppSettingsError?

    let label: () -> Label

    init(@ViewBuilder label: @escaping () -> Label) {
        self.label = label
    }

    var body: some View {
        Menu {
            Toggle("Open at Login", isOn: openAtLoginBinding)
            Divider()
            Button("About \(settings.appName)") {
                settings.showAboutPanel()
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
            get: { settings.isOpenAtLoginEnabled },
            set: { newValue in
                Task {
                    let result = await settings.setOpenAtLogin(newValue)
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

extension SettingsMenu where Label == Image {
    init() {
        self.init { Image(systemName: "gearshape.fill") }
    }
}

extension SettingsMenu where Label == Text {
    init(_ title: String) {
        self.init { Text(title) }
    }
}
