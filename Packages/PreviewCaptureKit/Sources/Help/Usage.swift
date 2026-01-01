//
//  Usage.swift
//  Help command output
//

public func printUsage() {
    print("""
    PreviewCapture - Visual verification tool for SwiftUI views

    Usage:
      swift run PreviewCapture              Capture all targets
      swift run PreviewCapture <name>       Capture specific target
      swift run PreviewCapture --list       List available targets
      swift run PreviewCapture --help       Show this help

    Output:
      PNG files and manifest.json are written to the output directory.
      Read manifest.json for structured results.
    """)
}
