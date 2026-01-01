//
//  ListScreenshots.swift
//  List available screenshots
//

import Foundation

@MainActor
public func listScreenshots<S: ScreenshotProvider>(_ provider: S.Type) {
    print("Available screenshots:")
    S.screenshots
        .map { "  - \($0.name) (\(Int($0.size.width))x\(Int($0.size.height)))" }
        .forEach { print($0) }
}
