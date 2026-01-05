//
//  FileDiscovery.swift
//  Discovers usage files in the filesystem
//

import Foundation

// MARK: - FileDiscovery

public enum FileDiscovery {

    // MARK: - Public API

    public static func discoverFiles(in basePath: String) throws -> [FileMetadata] {
        let projectsPath = basePath + Constants.projectsSubpath
        guard FileManager.default.fileExists(atPath: projectsPath) else {
            return []
        }

        return try discoverProjectDirectories(in: projectsPath)
            .flatMap { discoverJSONLFiles(in: $0) }
    }

    /// Filters files using the provided filter predicate
    public static func filter(
        _ files: [FileMetadata],
        by predicate: FileFilter
    ) -> [FileMetadata] {
        files.filter(predicate)
    }

    // MARK: - Directory Discovery

    private static func discoverProjectDirectories(in path: String) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: path)
            .map { buildFullPath(directory: path, item: $0) }
            .filter { isDirectory(at: $0) }
    }

    private static func discoverJSONLFiles(in projectDir: String) -> [FileMetadata] {
        createFileEnumerator(for: projectDir)
            .map { collectJSONLMetadata(from: $0, projectDir: projectDir) }
            ?? []
    }

    // MARK: - File Enumeration

    private static func createFileEnumerator(for directory: String) -> FileManager.DirectoryEnumerator? {
        FileManager.default.enumerator(
            at: URL(fileURLWithPath: directory),
            includingPropertiesForKeys: Constants.fileResourceKeys,
            options: [.skipsHiddenFiles]
        )
    }

    private static func collectJSONLMetadata(from enumerator: FileManager.DirectoryEnumerator, projectDir: String) -> [FileMetadata] {
        let projectName = extractLastPathComponent(from: projectDir)
        return enumerator
            .compactMap { $0 as? URL }
            .filter { isJSONLFile($0) }
            .compactMap { createMetadata(for: $0, projectDir: projectDir, projectName: projectName) }
    }

    // MARK: - Metadata Creation

    private static func createMetadata(
        for url: URL,
        projectDir: String,
        projectName: String
    ) -> FileMetadata? {
        guard let modificationDate = extractModificationDate(from: url) else {
            return nil
        }

        return FileMetadata(
            path: url.path,
            projectDir: projectDir,
            projectName: projectName,
            modificationDate: modificationDate
        )
    }

    private static func extractModificationDate(from url: URL) -> Date? {
        guard let values = try? url.resourceValues(forKeys: Set(Constants.fileResourceKeys)),
              values.isRegularFile == true else {
            return nil
        }
        return values.contentModificationDate
    }

    // MARK: - Path Utilities

    private static func extractLastPathComponent(from path: String) -> String {
        path.split(separator: Constants.pathSeparator)
            .last
            .flatMap { extractLastDashComponent(from: String($0)) }
            ?? path
    }

    private static func extractLastDashComponent(from segment: String) -> String {
        segment.split(separator: Constants.hashPathSeparator)
            .last
            .map(String.init)
            ?? segment
    }

    private static func buildFullPath(directory: String, item: String) -> String {
        directory + String(Constants.pathSeparator) + item
    }

    // MARK: - Predicates

    private static func isDirectory(at path: String) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    private static func isJSONLFile(_ url: URL) -> Bool {
        url.pathExtension == Constants.jsonlExtension
    }
}

// MARK: - Constants

private extension FileDiscovery {
    enum Constants {
        static let projectsSubpath = "/projects"
        static let jsonlExtension = "jsonl"
        static let pathSeparator: Character = "/"
        static let hashPathSeparator: Character = "-"
        static let fileResourceKeys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
    }
}
