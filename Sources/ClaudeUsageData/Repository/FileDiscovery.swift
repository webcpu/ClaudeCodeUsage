//
//  FileDiscovery.swift
//  ClaudeUsageData
//
//  Discovers and manages Claude usage files
//

import Foundation

// MARK: - FileDiscovery

public enum FileDiscovery {
    /// Discover all JSONL files in the projects directory
    public static func discoverFiles(in basePath: String) throws -> [FileMetadata] {
        let projectsPath = basePath + "/projects"
        guard FileManager.default.fileExists(atPath: projectsPath) else {
            return []
        }

        return try discoverProjectDirectories(in: projectsPath)
            .flatMap { projectDir in
                discoverJSONLFiles(in: projectDir)
            }
    }

    /// Filter files modified today
    public static func filterFilesModifiedToday(_ files: [FileMetadata]) -> [FileMetadata] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return files.filter { file in
            calendar.startOfDay(for: file.modificationDate) >= today
        }
    }

    /// Filter files modified within the specified hours
    public static func filterFilesModifiedWithin(_ files: [FileMetadata], hours: Double) -> [FileMetadata] {
        let cutoff = Date().addingTimeInterval(-hours * 3600)
        return files.filter { $0.modificationDate >= cutoff }
    }

    // MARK: - Private

    private static func discoverProjectDirectories(in path: String) throws -> [String] {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(atPath: path)

        return contents.compactMap { item in
            let fullPath = path + "/" + item
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                return nil
            }
            return fullPath
        }
    }

    private static func discoverJSONLFiles(in projectDir: String) -> [FileMetadata] {
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: projectDir),
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [FileMetadata] = []
        let projectName = extractProjectName(from: projectDir)

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "jsonl",
                  let metadata = createMetadata(for: fileURL, projectDir: projectDir, projectName: projectName) else {
                continue
            }
            files.append(metadata)
        }

        return files
    }

    private static func createMetadata(
        for url: URL,
        projectDir: String,
        projectName: String
    ) -> FileMetadata? {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
              values.isRegularFile == true,
              let modDate = values.contentModificationDate else {
            return nil
        }

        return FileMetadata(
            path: url.path,
            projectDir: projectDir,
            projectName: projectName,
            modificationDate: modDate
        )
    }

    private static func extractProjectName(from path: String) -> String {
        // Project dirs are hashed, e.g., "/Users/Projects/MyApp" -> "-Users-Projects-MyApp"
        // Extract the last meaningful component
        let components = path.split(separator: "/")
        guard let last = components.last else { return path }

        // The hash format uses dashes as path separators
        let parts = last.split(separator: "-")
        return parts.last.map(String.init) ?? String(last)
    }
}

// MARK: - FileMetadata

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

// MARK: - CachedFile

public struct CachedFile: Sendable {
    public let modificationDate: Date
    public let entries: [ClaudeUsageCore.UsageEntry]
    public let version: Int

    public init(modificationDate: Date, entries: [ClaudeUsageCore.UsageEntry], version: Int) {
        self.modificationDate = modificationDate
        self.entries = entries
        self.version = version
    }

    public static let currentVersion = 1
}
