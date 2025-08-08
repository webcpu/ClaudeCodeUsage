//
//  AppLifecycleManager.swift
//  Centralized app lifecycle and notification management
//

import SwiftUI
import Combine

@MainActor
final class AppLifecycleManager: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    private weak var dataModel: UsageDataModel?
    
    init() {
        setupNotificationHandlers()
    }
    
    func configure(with dataModel: UsageDataModel) {
        self.dataModel = dataModel
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
        dataModel?.handleAppBecameActive()
    }
    
    private func handleAppResignActive() {
        dataModel?.handleAppResignActive()
    }
    
    private func handleWindowFocus() {
        dataModel?.handleWindowFocus()
    }
    
    private func handleWindowWillClose() {
        dataModel?.stopRefreshTimer()
    }
}