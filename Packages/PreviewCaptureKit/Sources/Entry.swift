//
//  Entry.swift
//  Public entry point for PreviewCapture apps
//

import Foundation

/// Single entry point for PreviewCapture apps.
/// Usage: `await run(YourManifest.self)`
@MainActor
public func run<M: CaptureManifest>(_ manifest: M.Type) async {
    await execute(Command.parse(Array(CommandLine.arguments.dropFirst())), manifest: manifest)
}

@MainActor
func execute<M: CaptureManifest>(_ command: Command, manifest: M.Type) async {
    switch command {
    case .list:
        listTargets(manifest)
    case .help:
        printUsage()
    case .capture(let target):
        await executeCapture(manifest, target: target)
    }
}

@MainActor
func executeCapture<M: CaptureManifest>(_ manifest: M.Type, target: String?) async {
    do {
        try await runCapture(manifest, targetFilter: target)
        print("Capture complete.")
    } catch {
        print("Error: \(error)")
        exit(1)
    }
}
