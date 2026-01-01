//
//  Usage.swift
//  Help command output
//

public func printUsage() {
    print("""
    ScreenshotCapture - Visual verification tool for SwiftUI views

    Usage:
      swift run ScreenshotCapture              Capture all screenshots
      swift run ScreenshotCapture <name>       Capture specific screenshot
      swift run ScreenshotCapture --list       List available screenshots
      swift run ScreenshotCapture --help       Show this help

    Output:
      PNG files and manifest.json are written to the output directory.
      Read manifest.json for structured results.
    """)
}
