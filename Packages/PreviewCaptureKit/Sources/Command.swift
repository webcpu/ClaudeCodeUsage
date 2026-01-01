//
//  Command.swift
//  CLI command parsing
//

import Foundation

public enum Command {
    case list
    case help
    case capture(target: String?)

    public static func parse(_ args: [String]) -> Command {
        if args.contains("--list") { return .list }
        if args.contains("--help") || args.contains("-h") { return .help }
        return .capture(target: args.first { !$0.hasPrefix("-") })
    }
}
