//
//  JSONLParser.swift
//  ClaudeUsageData
//
//  Parses Claude JSONL usage files into UsageEntry models
//

import Foundation
import ClaudeUsageCore

// MARK: - JSONLParser

public struct JSONLParser: Sendable {
    public init() {}

    // Thread-safe cached formatter (read-only after init)
    nonisolated(unsafe) private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    // MARK: - Public API

    public func parseFile(
        at path: String,
        project: String,
        processedHashes: inout Set<String>
    ) -> [UsageEntry] {
        guard let fileData = loadFileData(at: path) else { return [] }
        let lines = extractLines(from: fileData)
        return lines.compactMap { lineData in
            parseEntry(from: lineData, path: path, project: project, processedHashes: &processedHashes)
        }
    }

    // MARK: - Entry Parsing

    private func parseEntry(
        from lineData: Data,
        path: String,
        project: String,
        processedHashes: inout Set<String>
    ) -> UsageEntry? {
        guard let rawData = decodeRawData(from: lineData),
              let validated = validateAssistantMessage(rawData),
              isUniqueEntry(rawData, validated, processedHashes: &processedHashes),
              let timestamp = parseTimestamp(validated.timestampStr) else {
            return nil
        }

        let tokens = createTokenCounts(from: validated.usage)
        guard tokens.total > 0 else { return nil }

        let model = validated.message.model ?? "<synthetic>"
        let cost = rawData.costUSD ?? PricingCalculator.calculateCost(tokens: tokens, model: model)

        return UsageEntry(
            id: createEntryId(validated.message.id, rawData.requestId, timestamp),
            timestamp: timestamp,
            model: model,
            tokens: tokens,
            costUSD: cost,
            project: project,
            sourceFile: path,
            sessionId: nil,
            messageId: validated.message.id,
            requestId: rawData.requestId
        )
    }

    // MARK: - File I/O

    private func loadFileData(at path: String) -> Data? {
        try? Data(contentsOf: URL(fileURLWithPath: path))
    }

    private func extractLines(from data: Data) -> [Data] {
        guard !data.isEmpty else { return [] }
        return [UInt8](data).withUnsafeBufferPointer { buffer in
            guard let ptr = buffer.baseAddress else { return [] }
            return buildLineRanges(ptr: ptr, count: data.count).map { data[$0] }
        }
    }

    // MARK: - Decoding

    private func decodeRawData(from lineData: Data) -> RawJSONLData? {
        guard !lineData.isEmpty else { return nil }
        return try? JSONDecoder().decode(RawJSONLData.self, from: lineData)
    }

    private func validateAssistantMessage(_ raw: RawJSONLData) -> ValidatedData? {
        guard let message = raw.message,
              let usage = message.usage,
              raw.type == "assistant",
              let timestampStr = raw.timestamp else {
            return nil
        }
        return ValidatedData(message: message, usage: usage, timestampStr: timestampStr)
    }

    private func isUniqueEntry(
        _ raw: RawJSONLData,
        _ validated: ValidatedData,
        processedHashes: inout Set<String>
    ) -> Bool {
        guard let hash = createDeduplicationHash(validated.message.id, raw.requestId) else {
            return true
        }
        return processedHashes.insert(hash).inserted
    }

    // MARK: - Transformations

    private func parseTimestamp(_ str: String) -> Date? {
        Self.dateFormatter.date(from: str)
    }

    private func createTokenCounts(from usage: RawJSONLData.Message.Usage) -> TokenCounts {
        TokenCounts(
            input: usage.input_tokens ?? 0,
            output: usage.output_tokens ?? 0,
            cacheCreation: usage.cache_creation_input_tokens ?? 0,
            cacheRead: usage.cache_read_input_tokens ?? 0
        )
    }

    private func createDeduplicationHash(_ messageId: String?, _ requestId: String?) -> String? {
        guard let messageId, let requestId else { return nil }
        return "\(messageId):\(requestId)"
    }

    private func createEntryId(_ messageId: String?, _ requestId: String?, _ timestamp: Date) -> String {
        if let messageId, let requestId {
            return "\(messageId):\(requestId)"
        }
        return "\(timestamp.timeIntervalSince1970)-\(UUID().uuidString)"
    }

    // MARK: - Line Extraction

    private func buildLineRanges(ptr: UnsafePointer<UInt8>, count: Int) -> [Range<Data.Index>] {
        var ranges: [Range<Data.Index>] = []
        var offset = 0

        while offset < count {
            let lineEnd = findLineEnd(ptr: ptr, offset: offset, count: count)
            if lineEnd > offset {
                ranges.append(offset..<lineEnd)
            }
            offset = lineEnd + 1
        }

        return ranges
    }

    private func findLineEnd(ptr: UnsafePointer<UInt8>, offset: Int, count: Int) -> Int {
        let remaining = count - offset
        if let found = memchr(ptr + offset, 0x0A, remaining) {
            return UnsafePointer(found.assumingMemoryBound(to: UInt8.self)) - ptr
        }
        return count
    }
}

// MARK: - Raw JSONL Data Model

struct RawJSONLData: Codable {
    let timestamp: String?
    let message: Message?
    let costUSD: Double?
    let type: String?
    let requestId: String?

    struct Message: Codable {
        let usage: Usage?
        let model: String?
        let id: String?

        struct Usage: Codable {
            let input_tokens: Int?
            let output_tokens: Int?
            let cache_creation_input_tokens: Int?
            let cache_read_input_tokens: Int?
        }
    }
}

private struct ValidatedData {
    let message: RawJSONLData.Message
    let usage: RawJSONLData.Message.Usage
    let timestampStr: String
}
