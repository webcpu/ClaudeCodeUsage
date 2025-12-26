//
//  AppLifecycleManager.swift
//  Centralized app lifecycle and notification management
//

import SwiftUI
import Observation
import Combine

@Observable
@MainActor
final class AppLifecycleManager {
    private var cancellables = Set<AnyCancellable>()
    private weak var store: UsageStore?

    init() {
        setupNotificationHandlers()
    }

    func configure(with store: UsageStore) {
        self.store = store
    }
    
    private func setupNotificationHandlers() {
        // App became active
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAppBecameActive()
            }
            .store(in: &cancellables)
        
        // App resigned active
        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAppResignActive()
            }
            .store(in: &cancellables)
        
        // Window became key
        NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleWindowFocus()
            }
            .store(in: &cancellables)
        
        // Window will close
        NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleWindowWillClose()
            }
            .store(in: &cancellables)
    }
    
    private func handleAppBecameActive() {
        store?.handleAppBecameActive()
    }

    private func handleAppResignActive() {
        store?.handleAppResignActive()
    }

    private func handleWindowFocus() {
        store?.handleWindowFocus()
    }

    private func handleWindowWillClose() {
        store?.stopRefreshTimer()
    }
}