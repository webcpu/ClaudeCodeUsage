//
//  UsageRepository+FileDiscovery.swift
//
//  File discovery and metadata extraction for usage repository.
//

import Foundation

// MARK: - File Discovery

extension UsageRepository {
    func discoverFiles(in projectsPath: String) throws -> [FileMetadata] {
        let todayStart = Calendar.current.startOfDay(for: Date())

        return try FileManager.default.contentsOfDirectory(atPath: projectsPath)
            .filter { !DirectoryFilter.shouldSkip($0) }
            .flatMap { projectDir in
                jsonlFiles(in: projectsPath + "/" + projectDir, projectDir: projectDir, todayStart: todayStart)
            }
            .sorted { $0.earliestTimestamp < $1.earliestTimestamp }
    }

    func jsonlFiles(in projectPath: String, projectDir: String, todayStart: Date) -> [FileMetadata] {
        (try? FileManager.default.contentsOfDirectory(atPath: projectPath))
            .map { files in
                files
                    .filter { $0.hasSuffix(".jsonl") }
                    .compactMap { buildMetadata(for: $0, in: projectPath, projectDir: projectDir, todayStart: todayStart) }
            } ?? []
    }

    func buildMetadata(
        for file: String,
        in projectPath: String,
        projectDir: String,
        todayStart: Date
    ) -> FileMetadata? {
        let filePath = projectPath + "/" + file

        if let cached = cachedMetadataForOldFile(at: filePath, projectDir: projectDir, todayStart: todayStart) {
            return cached
        }

        return freshMetadata(at: filePath, projectDir: projectDir)
    }

    func cachedMetadataForOldFile(at filePath: String, projectDir: String, todayStart: Date) -> FileMetadata? {
        guard let cached = fileCache[filePath],
              cached.modificationDate < todayStart else {
            return nil
        }

        // Validate cache: ensure file hasn't been modified since caching
        guard let actualModDate = FileTimestamp.modificationDate(of: filePath),
              actualModDate == cached.modificationDate else {
            return nil
        }

        return FileMetadata(
            path: filePath,
            projectDir: projectDir,
            earliestTimestamp: ISO8601DateFormatter().string(from: cached.modificationDate),
            modificationDate: cached.modificationDate
        )
    }

    func freshMetadata(at filePath: String, projectDir: String) -> FileMetadata? {
        guard let (timestamp, modDate) = FileTimestamp.extract(from: filePath) else {
            return nil
        }
        return FileMetadata(
            path: filePath,
            projectDir: projectDir,
            earliestTimestamp: timestamp,
            modificationDate: modDate
        )
    }

    func filterFilesModifiedToday(_ files: [FileMetadata]) -> [FileMetadata] {
        let todayStart = Calendar.current.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()
        return files.filter { file in
            formatter.date(from: file.earliestTimestamp).map { $0 >= todayStart } ?? false
        }
    }

    func countSessions(in files: [FileMetadata]) -> Int {
        Set(
            files.compactMap { file in
                let filename = URL(fileURLWithPath: file.path).lastPathComponent
                return filename.hasSuffix(".jsonl") ? String(filename.dropLast(6)) : nil
            }
        ).count
    }
}

// MARK: - Directory Filter

enum DirectoryFilter {
    static func shouldSkip(_ name: String) -> Bool {
        name.hasPrefix("-private-var-folders-") ||
        name.hasPrefix(".")
    }
}

// MARK: - Path Decoder

enum PathDecoder {
    static func decode(_ encodedPath: String) -> String {
        if encodedPath.hasPrefix("-") {
            return "/" + String(encodedPath.dropFirst()).replacingOccurrences(of: "-", with: "/")
        }
        return encodedPath.replacingOccurrences(of: "-", with: "/")
    }
}

// MARK: - File Timestamp

enum FileTimestamp {
    /// Extract both timestamp string and modification date from file
    static func extract(from path: String) -> (timestamp: String, modificationDate: Date)? {
        guard let modDate = modificationDate(of: path) else {
            return nil
        }
        return (ISO8601DateFormatter().string(from: modDate), modDate)
    }

    /// Get modification date for cache validation
    static func modificationDate(of path: String) -> Date? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let modDate = attributes[.modificationDate] as? Date else {
            return nil
        }
        return modDate
    }
}
