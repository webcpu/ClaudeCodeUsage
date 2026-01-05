//
//  CachedFile.swift
//  Cache entry for parsed usage files
//

import Foundation

public struct CachedFile: Sendable {
    public let modificationDate: Date
    public let entries: [UsageEntry]
    public let version: Int

    public init(modificationDate: Date, entries: [UsageEntry], version: Int) {
        self.modificationDate = modificationDate
        self.entries = entries
        self.version = version
    }

    public static let currentVersion = 1
}
