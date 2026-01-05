//
//  FileMetadata.swift
//  Metadata about discovered usage files
//

import Foundation

public struct FileMetadata: Sendable, Hashable {
    public let path: String
    public let projectDir: String
    public let projectName: String
    public let modificationDate: Date

    public init(path: String, projectDir: String, projectName: String, modificationDate: Date) {
        self.path = path
        self.projectDir = projectDir
        self.projectName = projectName
        self.modificationDate = modificationDate
    }
}
