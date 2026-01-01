//
//  Entry.swift
//  Public entry point for ScreenshotCapture apps
//

import Foundation

/// Single entry point for ScreenshotCapture apps.
/// Usage: `await run(Screenshots.self)`
@MainActor
public func run<S: ScreenshotProvider>(_ provider: S.Type) async {
    await execute(Command.parse(Array(CommandLine.arguments.dropFirst())), provider: provider)
}

@MainActor
func execute<S: ScreenshotProvider>(_ command: Command, provider: S.Type) async {
    switch command {
    case .list:
        listScreenshots(provider)
    case .help:
        printUsage()
    case .capture(let name):
        await executeCapture(provider, name: name)
    }
}

@MainActor
func executeCapture<S: ScreenshotProvider>(_ provider: S.Type, name: String?) async {
    do {
        try await captureScreenshots(provider, filter: name)
        print("Capture complete.")
    } catch {
        print("Error: \(error)")
        exit(1)
    }
}
