//
//  AppSettingsService.swift
//  Centralized settings management with proper architecture
//

import Foundation
import ServiceManagement
import SwiftUI
import Observation
import OSLog

private let logger = Logger(subsystem: "com.claudecodeusage", category: "AppSettings")

// MARK: - Protocol

@MainActor
protocol AppSettingsServiceProtocol: AnyObject {
    var isOpenAtLoginEnabled: Bool { get }
    func setOpenAtLogin(_ enabled: Bool) async -> Result<Void, AppSettingsError>
    func showAboutPanel()
}

// MARK: - Main Implementation

@Observable
@MainActor
public final class AppSettingsService: AppSettingsServiceProtocol {
    public private(set) var isOpenAtLoginEnabled: Bool = false

    public var appName: String { AppMetadata.name }

    public init() {
        refreshLoginStatus()
    }

    // MARK: - Public API (High-Level Intent)

    public func setOpenAtLogin(_ enabled: Bool) async -> Result<Void, AppSettingsError> {
        guard #available(macOS 13.0, *) else {
            return .failure(.unsupportedOS)
        }

        guard needsChange(to: enabled) else {
            return .success(())
        }

        do {
            try await updateServiceRegistration(enabled: enabled)
            refreshLoginStatus()
            return .success(())
        } catch {
            logger.error("Failed to set launch at login: \(error.localizedDescription)")
            return .failure(.serviceManagementFailed(error))
        }
    }

    public func showAboutPanel() {
        NSApp.orderFrontStandardAboutPanel(options: aboutPanelOptions)
    }

    // MARK: - Private Helpers (Infrastructure)

    @available(macOS 13.0, *)
    private func needsChange(to enabled: Bool) -> Bool {
        let currentlyEnabled = SMAppService.mainApp.status == .enabled
        return currentlyEnabled != enabled
    }

    @available(macOS 13.0, *)
    private func updateServiceRegistration(enabled: Bool) async throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try await SMAppService.mainApp.unregister()
        }
    }

    private func refreshLoginStatus() {
        guard #available(macOS 13.0, *) else {
            isOpenAtLoginEnabled = false
            return
        }
        isOpenAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }

    private var aboutPanelOptions: [NSApplication.AboutPanelOptionKey: Any] {
        [
            .applicationName: AppMetadata.name,
            .applicationVersion: AppMetadata.version,
            .credits: NSAttributedString(
                string: AppMetadata.credits,
                attributes: [.font: NSFont.systemFont(ofSize: 11)]
            )
        ]
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
        logger.debug("About panel shown")
    }
}
#endif

// MARK: - Supporting Types

public enum AppSettingsError: LocalizedError {
    case serviceManagementFailed(Error)
    case permissionDenied
    case unsupportedOS

    public var errorDescription: String? {
        switch self {
        case .serviceManagementFailed(let error):
            return "Failed to update launch settings: \(error.localizedDescription)"
        case .permissionDenied:
            return "Permission denied. Please check System Settings > Login Items."
        case .unsupportedOS:
            return "Open at Login requires macOS 13.0 or later"
        }
    }

    public var recoverySuggestion: String? {
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

public enum AppMetadata {
    public static let name = "Claude Usage"
    public static let version = "1.0.0"
    public static let credits = "Claude Code Usage Tracking"
}
