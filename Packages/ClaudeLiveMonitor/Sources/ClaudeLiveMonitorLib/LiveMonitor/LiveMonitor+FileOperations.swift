//
//  LiveMonitor+FileOperations.swift
//
//  File discovery and loading operations for LiveMonitor.
//

import Foundation

// MARK: - File Discovery

extension LiveMonitor {

    func findUsageFiles() -> [String] {
        config.claudePaths.flatMap { findJSONLFiles(in: $0) }
    }

    private func findJSONLFiles(in claudePath: String) -> [String] {
        let projectsPath = "\(claudePath)/projects"
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: projectsPath),
              let enumerator = fileManager.enumerator(atPath: projectsPath) else {
            return []
        }

        return enumerator
            .compactMap { $0 as? String }
            .filter { $0.hasSuffix(".jsonl") }
            .map { "\(projectsPath)/\($0)" }
    }
}

// MARK: - File Loading

extension LiveMonitor {

    func loadModifiedFiles(_ files: [String]) {
        let filesToRead = files.filter { isFileModified($0) }
        guard !filesToRead.isEmpty else { return }

        loadEntriesFromFiles(filesToRead)
    }

    private func isFileModified(_ file: String) -> Bool {
        guard let timestamp = fileModificationTime(file) else { return false }
        let wasModified = lastFileTimestamps[file].map { timestamp > $0 } ?? true
        if wasModified {
            lastFileTimestamps[file] = timestamp
        }
        return wasModified
    }

    private func fileModificationTime(_ path: String) -> Date? {
        try? FileManager.default
            .attributesOfItem(atPath: path)[.modificationDate] as? Date
    }

    private func loadEntriesFromFiles(_ files: [String]) {
        let newEntries = files.flatMap { parser.parseFile(at: $0, processedHashes: &processedHashes) }
        allEntries.append(contentsOf: newEntries)
        allEntries.sort { $0.timestamp < $1.timestamp }
    }
}
