//
//  PreviewCaptureApp.swift
//  PreviewCapture entry point
//
//  Usage:
//    swift run PreviewCapture              # Capture all targets
//    swift run PreviewCapture MenuBar      # Capture specific target
//    swift run PreviewCapture --list       # List available targets
//

import Foundation
@testable import ClaudeUsageUI

@main
struct PreviewCaptureApp {
    static func main() async {
        await execute(Command.parse(Array(CommandLine.arguments.dropFirst())))
    }

    private static func execute(_ command: Command) async {
        switch command {
        case .list:
            await listTargets(AppEnvironment.self)
        case .help:
            printUsage()
        case .capture(let target):
            await executeCapture(target: target)
        }
    }

    private static func executeCapture(target: String?) async {
        do {
            try await runCapture(AppEnvironment.self, targetFilter: target)
            print("Capture complete.")
        } catch {
            print("Error: \(error)")
            exit(1)
        }
    }
}
