//
//  SessionProvider.swift
//  Provides active session data from usage files
//

import Foundation

// MARK: - SessionProvider

/// Provides active session data by reading usage files.
///
/// Responsibilities:
/// - File discovery and loading (I/O)
/// - Cache management
/// - Delegates session finding to SessionFinder (Domain)
public actor SessionProvider: SessionProviding {
    private let basePath: String
    private let parser = JSONLParser()
    private let finder: SessionFinder

    private var lastFileTimestamps: [String: Date] = [:]
    private var allEntries: [UsageEntry] = []
    private var cachedTokenLimit: Int = 0
    private var cachedSession: (session: UsageSession?, timestamp: Date)?

    // MARK: - Initialization

    public init(basePath: String = NSHomeDirectory() + "/.claude", sessionDurationHours: Double = 5.0) {
        self.basePath = basePath
        self.finder = SessionFinder(sessionDurationHours: sessionDurationHours)
    }

    // MARK: - SessionProviding

    public func getActiveSession() async -> UsageSession? {
        if let cached = cachedSession, isCacheValid(cached.timestamp) {
            return cached.session
        }

        let session = loadActiveSession()
        cachedSession = (session, Date())
        return session
    }

    // MARK: - Cache Management

    public func clearCache() {
        lastFileTimestamps.removeAll()
        allEntries.removeAll()
        cachedTokenLimit = 0
        cachedSession = nil
    }

    // MARK: - Session Loading

    private func loadActiveSession() -> UsageSession? {
        loadModifiedFiles()
        let now = Date()
        let blocks = finder.findSessions(from: allEntries, now: now)
        cachedTokenLimit = finder.maxTokensFromCompletedSessions(blocks)
        return finder.findActiveSession(in: blocks)?
            .with(tokenLimit: cachedTokenLimit > 0 ? cachedTokenLimit : nil)
    }

    // MARK: - File Loading

    private func loadModifiedFiles() {
        let files = findUsageFiles()
        files
            .filter(shouldReloadFile)
            .forEach(reloadFile)
        allEntries.sort()
    }

    private func findUsageFiles() -> [FileMetadata] {
        guard let allFiles = try? FileDiscovery.discoverFiles(in: basePath) else {
            return []
        }
        let windowHours = finder.sessionDurationHours * 2
        return FileDiscovery.filter(allFiles, by: FileFilters.modifiedWithin(hours: windowHours))
    }

    private func reloadFile(_ file: FileMetadata) {
        var fileHashes = Set<String>()
        let newEntries = parser.parseFile(
            at: file.path,
            project: file.projectName,
            processedHashes: &fileHashes
        )
        allEntries.removeAll { $0.sourceFile == file.path }
        allEntries.append(contentsOf: newEntries)
        lastFileTimestamps[file.path] = file.modificationDate
    }

    private func shouldReloadFile(_ file: FileMetadata) -> Bool {
        guard let lastTimestamp = lastFileTimestamps[file.path] else {
            return true
        }
        return file.modificationDate > lastTimestamp
    }

    // MARK: - Cache Validation

    private func isCacheValid(_ timestamp: Date) -> Bool {
        Date().timeIntervalSince(timestamp) < 2.0
    }
}
