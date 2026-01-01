//
//  ListTargets.swift
//  List available capture targets
//

import Foundation
@testable import ClaudeUsageUI

@MainActor
func listTargets<M: CaptureManifest>(_ manifest: M.Type) {
    print("Available capture targets:")
    M.targets
        .map { "  - \($0.name) (\(Int($0.size.width))x\(Int($0.size.height)))" }
        .forEach { print($0) }
}
