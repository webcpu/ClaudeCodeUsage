//
//  AppLifecycleManager.swift
//  Centralized app lifecycle and notification management
//

import SwiftUI
import Observation
import Combine

@Observable
@MainActor
public final class AppLifecycleManager {
    private var cancellables = Set<AnyCancellable>()
    private weak var store: SessionStore?

    public init() {
        setupNotificationHandlers()
    }

    public func configure(with store: SessionStore) {
        self.store = store
    }
    
    private func setupNotificationHandlers() {
        observe(NSApplication.didBecomeActiveNotification) { [weak self] in self?.handleAppBecameActive() }
        observe(NSApplication.didResignActiveNotification) { [weak self] in self?.handleAppResignActive() }
        observe(NSWindow.didBecomeKeyNotification) { [weak self] in self?.handleWindowFocus() }
        observe(NSWindow.willCloseNotification) { [weak self] in self?.handleWindowWillClose() }
    }

    private func observe(_ notification: NSNotification.Name, handler: @escaping () -> Void) {
        NotificationCenter.default.publisher(for: notification)
            .receive(on: DispatchQueue.main)
            .sink { _ in handler() }
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
        // Menu bar popover closing should NOT stop monitoring.
        // Day change and file change observers must stay active.
    }
}