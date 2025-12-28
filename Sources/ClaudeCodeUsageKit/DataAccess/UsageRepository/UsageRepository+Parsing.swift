//
//  UsageRepository+Parsing.swift
//
//  Entry loading, parsing, and transformation utilities.
//

import Foundation

// MARK: - Entry Loading

extension UsageRepository {
    func loadEntries(from files: [FileMetadata]) async -> [UsageEntry] {
        let (cachedFiles, dirtyFiles) = partitionByCache(files)
        let cachedEntries = cachedFiles.flatMap { fileCache[$0.path]?.entries ?? [] }
        let newEntries = await loadNewEntries(from: dirtyFiles, deduplication: globalDeduplication)
        return cachedEntries + newEntries
    }

    func partitionByCache(_ files: [FileMetadata]) -> (cached: [FileMetadata], dirty: [FileMetadata]) {
        files.reduce(into: (cached: [FileMetadata](), dirty: [FileMetadata]())) { result, file in
            if isCacheHit(for: file) {
                result.cached.append(file)
            } else {
                result.dirty.append(file)
            }
        }
    }

    func isCacheHit(for file: FileMetadata) -> Bool {
        guard let cached = fileCache[file.path] else { return false }
        return cached.modificationDate == file.modificationDate && cached.version == CacheVersion.current
    }

    func loadNewEntries(from files: [FileMetadata], deduplication: Deduplication) async -> [UsageEntry] {
        switch files.count {
        case 0:
            return []
        case 1...RepositoryThreshold.parallelProcessing:
            return loadEntriesSequentially(from: files, deduplication: deduplication)
        case (RepositoryThreshold.parallelProcessing + 1)...RepositoryThreshold.batchProcessing:
            return await loadEntriesInParallel(from: files, deduplication: deduplication)
        default:
            return await loadEntriesInBatches(from: files, deduplication: deduplication)
        }
    }

    func loadEntriesSequentially(
        from files: [FileMetadata],
        deduplication: Deduplication
    ) -> [UsageEntry] {
        files.flatMap { parseFile($0, deduplication: deduplication) }
    }

    func loadEntriesInParallel(
        from files: [FileMetadata],
        deduplication: Deduplication
    ) async -> [UsageEntry] {
        let results = await parseFilesInParallel(files, deduplication: deduplication)
        return cacheAndExtractEntries(from: results)
    }

    func parseFilesInParallel(
        _ files: [FileMetadata],
        deduplication: Deduplication
    ) async -> [(FileMetadata, [UsageEntry])] {
        await withTaskGroup(of: (FileMetadata, [UsageEntry]).self) { group in
            files.forEach { file in
                group.addTask { (file, FileParser.parse(file, deduplication: deduplication)) }
            }
            return await group.reduce(into: []) { $0.append($1) }
        }
    }

    func cacheAndExtractEntries(from results: [(FileMetadata, [UsageEntry])]) -> [UsageEntry] {
        results.flatMap { file, entries in
            fileCache[file.path] = CachedFile(modificationDate: file.modificationDate, entries: entries, version: CacheVersion.current)
            return entries
        }
    }

    func loadEntriesInBatches(
        from files: [FileMetadata],
        deduplication: Deduplication
    ) async -> [UsageEntry] {
        await batches(of: files, size: RepositoryThreshold.batchSize)
            .asyncFlatMap { [self] in await loadEntriesInParallel(from: $0, deduplication: deduplication) }
    }

    func batches(of files: [FileMetadata], size: Int) -> [[FileMetadata]] {
        stride(from: 0, to: files.count, by: size).map { startIndex in
            Array(files[startIndex..<min(startIndex + size, files.count)])
        }
    }

    func parseFile(_ file: FileMetadata, deduplication: Deduplication) -> [UsageEntry] {
        let entries = FileParser.parse(file, deduplication: deduplication)
        fileCache[file.path] = CachedFile(modificationDate: file.modificationDate, entries: entries, version: CacheVersion.current)
        return entries
    }
}

// MARK: - JSON Validator

enum JSONValidator {
    static func isValidObject(_ data: Data) -> Bool {
        data.count > 2 &&
        data.first == ByteValue.openBrace &&
        data.last == ByteValue.closeBrace
    }
}

// MARK: - Line Scanner

enum LineScanner {
    static func extractRanges(from data: Data) -> [Range<Data.Index>] {
        guard data.count > 0 else { return [] }

        return [UInt8](data).withUnsafeBufferPointer { buffer in
            guard let ptr = buffer.baseAddress else { return [] }
            var ranges: [Range<Int>] = []
            var offset = 0

            while offset < data.count {
                let remaining = data.count - offset
                let lineEnd = memchr(ptr + offset, ByteValue.newline, remaining)
                    .map { UnsafePointer($0.assumingMemoryBound(to: UInt8.self)) - ptr }
                    ?? data.count

                if lineEnd > offset {
                    ranges.append(offset..<lineEnd)
                }
                offset = lineEnd + 1
            }
            return ranges
        }
    }
}

// MARK: - Entry Parser

enum EntryParser {
    static func parse(_ json: [String: Any], projectPath: String) -> UsageEntry? {
        guard let message = json["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any] else {
            return nil
        }

        let tokens = extractTokens(from: usage)
        guard tokens.hasUsage else { return nil }

        let model = message["model"] as? String ?? "unknown"
        let cost = calculateCost(json: json, model: model, tokens: tokens)

        return UsageEntry(
            project: projectPath,
            timestamp: json["timestamp"] as? String ?? "",
            model: model,
            inputTokens: tokens.input,
            outputTokens: tokens.output,
            cacheWriteTokens: tokens.cacheWrite,
            cacheReadTokens: tokens.cacheRead,
            cost: cost,
            sessionId: json["sessionId"] as? String
        )
    }

    private static func extractTokens(from usage: [String: Any]) -> TokenCounts {
        TokenCounts(
            input: usage["input_tokens"] as? Int ?? 0,
            output: usage["output_tokens"] as? Int ?? 0,
            cacheWrite: usage["cache_creation_input_tokens"] as? Int ?? 0,
            cacheRead: usage["cache_read_input_tokens"] as? Int ?? 0
        )
    }

    private static func calculateCost(json: [String: Any], model: String, tokens: TokenCounts) -> Double {
        if let cost = json["costUSD"] as? Double, cost > 0 {
            return cost
        }
        return ModelPricing.pricing(for: model)?.calculateCost(
            inputTokens: tokens.input,
            outputTokens: tokens.output,
            cacheWriteTokens: tokens.cacheWrite,
            cacheReadTokens: tokens.cacheRead
        ) ?? 0.0
    }

    struct TokenCounts {
        let input: Int
        let output: Int
        let cacheWrite: Int
        let cacheRead: Int

        var hasUsage: Bool {
            input > 0 || output > 0 || cacheWrite > 0 || cacheRead > 0
        }
    }
}

// MARK: - File Parser

enum FileParser {
    /// Pure file parsing function - no actor isolation, safe for concurrent execution
    static func parse(_ file: FileMetadata, deduplication: Deduplication) -> [UsageEntry] {
        guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: file.path)) else {
            return []
        }

        let projectPath = PathDecoder.decode(file.projectDir)
        return LineScanner.extractRanges(from: fileData)
            .compactMap { range -> UsageEntry? in
                let lineData = fileData[range]
                guard JSONValidator.isValidObject(lineData),
                      let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      deduplication.shouldInclude(json: json) else {
                    return nil
                }
                return EntryParser.parse(json, projectPath: projectPath)
            }
    }
}

// MARK: - Deduplication

final class Deduplication: @unchecked Sendable {
    private var processedHashes: Set<String> = []
    private let queue = DispatchQueue(label: "com.claudeusage.deduplication", attributes: .concurrent)

    func shouldInclude(json: [String: Any]) -> Bool {
        guard let message = json["message"] as? [String: Any],
              let messageId = message["id"] as? String,
              let requestId = json["requestId"] as? String else {
            return true
        }

        let uniqueHash = "\(messageId):\(requestId)"
        var shouldInclude = false
        queue.sync(flags: .barrier) {
            if !processedHashes.contains(uniqueHash) {
                processedHashes.insert(uniqueHash)
                shouldInclude = true
            }
        }
        return shouldInclude
    }
}
