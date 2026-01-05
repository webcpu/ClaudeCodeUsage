//
//  WindowActions.swift
//  Window management utilities
//

import SwiftUI

// MARK: - Window Actions

public enum WindowActions {
    @MainActor
    public static func showMainWindow() {
        let targetScreen = captureScreenAtMouseLocation()
        activateApp()
        findAndShowWindow(on: targetScreen)
    }

    @MainActor
    private static func captureScreenAtMouseLocation() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main
    }

    @MainActor
    private static func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    private static func findAndShowWindow(on targetScreen: NSScreen?) {
        guard let window = NSApp.windows.first(where: { $0.title == AppMetadata.name }) else { return }
        moveToActiveSpace(window)
        restoreIfMinimized(window)
        window.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { centerWindow(window, on: targetScreen) }
    }

    @MainActor
    private static func moveToActiveSpace(_ window: NSWindow) {
        window.collectionBehavior.insert(.moveToActiveSpace)
    }

    @MainActor
    private static func restoreIfMinimized(_ window: NSWindow) {
        if window.isMiniaturized { window.deminiaturize(nil) }
    }

    @MainActor
    private static func centerWindow(_ window: NSWindow, on screen: NSScreen?) {
        guard let screen else { return }
        let frame = screen.visibleFrame
        let size = window.frame.size
        let origin = CGPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2)
        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}
