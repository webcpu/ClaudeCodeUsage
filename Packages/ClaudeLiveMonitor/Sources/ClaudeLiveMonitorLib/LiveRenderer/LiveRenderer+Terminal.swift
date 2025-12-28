//
//  LiveRenderer+Terminal.swift
//
//  Terminal display infrastructure: layout constants, ANSI colors,
//  progress bar builder, and string formatting utilities.
//

import Foundation

// MARK: - Layout Constants

enum Layout {
    static let width = 80
    static let contentWidth = width - 2
    static let divider = String(repeating: "\u{2500}", count: contentWidth)
    static let verticalBorder = "\u{2502}"

    static let title = "CLAUDE CODE - LIVE TOKEN USAGE MONITOR"
    static let footerText = "\u{21BB} Refreshing every 1s  \u{2022}  Press Ctrl+C to stop"

    static let sessionIcon = "\u{23F1}\u{FE0F}"
    static let usageIcon = "\u{1F525}"
    static let projectionIcon = "\u{1F4C8}"
    static let modelsIcon = "\u{2699}\u{FE0F}"
}

// MARK: - Border Position

enum BorderPosition {
    case top, middle, bottom

    var corners: (String, String) {
        switch self {
        case .top: ("\u{250C}", "\u{2510}")
        case .middle: ("\u{251C}", "\u{2524}")
        case .bottom: ("\u{2514}", "\u{2518}")
        }
    }
}

// MARK: - Terminal Control

enum Terminal {
    static let clearScreenSequence = "\u{001B}[2J\u{001B}[H"

    static func clearScreen() {
        print(clearScreenSequence, terminator: "")
    }
}

// MARK: - ANSI Colors

enum ANSIColor: String {
    case red = "\u{001B}[31m"
    case yellow = "\u{001B}[33m"
    case green = "\u{001B}[32m"
    case gray = "\u{001B}[90m"
    case reset = "\u{001B}[0m"

    func wrap(_ text: String) -> String {
        "\(rawValue)\(text)\(ANSIColor.reset.rawValue)"
    }
}

// MARK: - Progress Bar Builder

enum ProgressBar {
    static let width = 30

    static func build(percentage: Double, color: ANSIColor) -> String {
        let clampedPercentage = min(max(percentage, 0), 100)
        let filled = Int(Double(width) * clampedPercentage / 100)
        let empty = width - filled

        let filledPart = color.wrap(String(repeating: "\u{2588}", count: filled))
        let emptyPart = ANSIColor.gray.wrap(String(repeating: "\u{2591}", count: empty))

        return filledPart + emptyPart
    }
}

// MARK: - String Formatting Extensions

extension String {
    func padded(to width: Int) -> String {
        padding(toLength: width, withPad: " ", startingAt: 0)
    }

    func centered(in width: Int) -> String {
        let padding = max(0, width - count)
        let leftPad = padding / 2
        let rightPad = padding - leftPad
        return String(repeating: " ", count: leftPad) + self + String(repeating: " ", count: rightPad)
    }
}
