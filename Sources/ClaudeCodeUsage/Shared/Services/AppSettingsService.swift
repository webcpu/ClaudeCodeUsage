//
//  AppSettingsService.swift
//  Centralized settings management with proper architecture
//

import Foundation
import ServiceManagement
import SwiftUI
import Observation

// MARK: - Protocol for Dependency Injection
@MainActor
protocol AppSettingsServiceProtocol: AnyObject {
    var isOpenAtLoginEnabled: Bool { get }
    func setOpenAtLogin(_ enabled: Bool) async -> Result<Void, AppSettingsError>
    func showAboutPanel()
}

// MARK: - Error Handling
enum AppSettingsError: LocalizedError {
    case serviceManagementFailed(Error)
    case permissionDenied
    case unsupportedOS
    
    var errorDescription: String? {
        switch self {
        case .serviceManagementFailed(let error):
            return "Failed to update launch settings: \(error.localizedDescription)"
        case .permissionDenied:
            return "Permission denied. Please check System Settings > Login Items."
        case .unsupportedOS:
            return "Open at Login requires macOS 13.0 or later"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .serviceManagementFailed:
            return "Try again or check System Settings > Login Items"
        case .permissionDenied:
            return "Grant permission in System Settings"
        case .unsupportedOS:
            return "Update to macOS 13.0 or later"
        }
    }
}

// MARK: - Main Implementation
@Observable
@MainActor
final class AppSettingsService: AppSettingsServiceProtocol {
    private(set) var isOpenAtLoginEnabled: Bool = false
    
    // App metadata
    let appName = "Usage Dashboard"
    let appVersion = "1.0.0"
    let appCredits = "Claude Code Usage Tracking"
    
    init() {
        Task {
            await checkOpenAtLoginStatus()
        }
    }
    
    // MARK: - Open at Login Management
    
    func setOpenAtLogin(_ enabled: Bool) async -> Result<Void, AppSettingsError> {
        guard #available(macOS 13.0, *) else {
            return .failure(.unsupportedOS)
        }
        
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled {
                    return .success(())
                }
                try SMAppService.mainApp.register()
            } else {
                if SMAppService.mainApp.status != .enabled {
                    return .success(())
                }
                try await SMAppService.mainApp.unregister()
            }
            
            await checkOpenAtLoginStatus()
            return .success(())
        } catch {
            print("[AppSettings] Failed to set launch at login: \(error)")
            return .failure(.serviceManagementFailed(error))
        }
    }
    
    @MainActor
    private func checkOpenAtLoginStatus() async {
        guard #available(macOS 13.0, *) else {
            isOpenAtLoginEnabled = false
            return
        }
        
        isOpenAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }
    
    // MARK: - About Panel
    
    func showAboutPanel() {
        NSApp.orderFrontStandardAboutPanel(
            options: [
                .applicationName: appName,
                .applicationVersion: appVersion,
                .credits: NSAttributedString(
                    string: appCredits,
                    attributes: [.font: NSFont.systemFont(ofSize: 11)]
                )
            ]
        )
    }
}

// MARK: - Mock for Testing
#if DEBUG
@Observable
@MainActor
final class MockAppSettingsService: AppSettingsServiceProtocol {
    private(set) var isOpenAtLoginEnabled: Bool = false
    
    func setOpenAtLogin(_ enabled: Bool) async -> Result<Void, AppSettingsError> {
        isOpenAtLoginEnabled = enabled
        return .success(())
    }
    
    func showAboutPanel() {
        print("[Mock] About panel shown")
    }
}
#endif