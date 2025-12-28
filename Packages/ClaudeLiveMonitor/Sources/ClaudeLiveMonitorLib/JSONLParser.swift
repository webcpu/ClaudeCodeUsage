import Foundation

// MARK: - JSONLParser

public struct JSONLParser {
    private let dateFormatter: ISO8601DateFormatter
    private let decoder: JSONDecoder

    public init() {
        self.dateFormatter = ISO8601DateFormatter()
        self.dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.decoder = JSONDecoder()
    }

    // MARK: - Public API

    public func parseFile(at path: String, processedHashes: inout Set<String>) -> [UsageEntry] {
        guard let fileData = loadFileData(at: path) else { return [] }
        let lineDataSequence = extractLines(from: fileData)
        return lineDataSequence.compactMap { lineData in
            parseEntry(from: lineData, path: path, processedHashes: &processedHashes)
        }
    }

    // MARK: - Orchestration

    private func parseEntry(
        from lineData: Data,
        path: String,
        processedHashes: inout Set<String>
    ) -> UsageEntry? {
        guard let usageData = decodeUsageData(from: lineData),
              let validatedData = validateAssistantMessage(usageData),
              isUniqueEntry(usageData, validatedData, processedHashes: &processedHashes),
              let timestamp = parseTimestamp(validatedData.timestampStr),
              let tokenCounts = createTokenCounts(from: validatedData.usage),
              tokenCounts.total > 0 else {
            return nil
        }

        let model = validatedData.message.model ?? Constants.syntheticModel
        let cost = calculateCost(usageData: usageData, model: model, tokens: tokenCounts)

        return UsageEntry(
            timestamp: timestamp,
            usage: tokenCounts,
            costUSD: cost,
            model: model,
            sourceFile: path,
            messageId: validatedData.message.id,
            requestId: usageData.requestId
        )
    }

    // MARK: - File I/O

    private func loadFileData(at path: String) -> Data? {
        try? Data(contentsOf: URL(fileURLWithPath: path))
    }

    private func extractLines(from data: Data) -> [Data] {
        extractLineRanges(from: data).map { data[$0] }
    }

    // MARK: - Decoding

    private func decodeUsageData(from lineData: Data) -> JSONLUsageData? {
        guard !lineData.isEmpty else { return nil }
        return try? decoder.decode(JSONLUsageData.self, from: lineData)
    }

    // MARK: - Validation

    private func validateAssistantMessage(_ usageData: JSONLUsageData) -> ValidatedUsageData? {
        guard let message = usageData.message,
              let usage = message.usage,
              usageData.type == Constants.assistantType,
              let timestampStr = usageData.timestamp else {
            return nil
        }
        return ValidatedUsageData(message: message, usage: usage, timestampStr: timestampStr)
    }

    private func isUniqueEntry(
        _ usageData: JSONLUsageData,
        _ data: ValidatedUsageData,
        processedHashes: inout Set<String>
    ) -> Bool {
        guard let hash = createDeduplicationHash(
            messageId: data.message.id,
            requestId: usageData.requestId
        ) else {
            return true
        }
        return processedHashes.insert(hash).inserted
    }

    // MARK: - Pure Transformations

    private func parseTimestamp(_ timestampStr: String) -> Date? {
        dateFormatter.date(from: timestampStr)
    }

    private func createTokenCounts(from usage: JSONLUsageData.Message.Usage) -> TokenCounts? {
        TokenCounts(
            inputTokens: usage.input_tokens ?? 0,
            outputTokens: usage.output_tokens ?? 0,
            cacheCreationInputTokens: usage.cache_creation_input_tokens ?? 0,
            cacheReadInputTokens: usage.cache_read_input_tokens ?? 0
        )
    }

    private func createDeduplicationHash(messageId: String?, requestId: String?) -> String? {
        guard let messageId, let requestId else { return nil }
        return "\(messageId):\(requestId)"
    }

    private func calculateCost(
        usageData: JSONLUsageData,
        model: String,
        tokens: TokenCounts
    ) -> Double {
        if let costUSD = usageData.costUSD {
            return costUSD
        }
        let pricing = ModelPricing.getPricing(for: model)
        return pricing.calculateCost(tokens: tokens)
    }

    // MARK: - Line Extraction (SIMD-optimized)

    private func extractLineRanges(from data: Data) -> [Range<Data.Index>] {
        let count = data.count
        guard count > 0 else { return [] }

        return [UInt8](data).withUnsafeBufferPointer { buffer in
            guard let ptr = buffer.baseAddress else { return [] }
            return buildLineRanges(ptr: ptr, count: count)
        }
    }

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
        if let found = memchr(ptr + offset, Constants.newlineByte, remaining) {
            return UnsafePointer(found.assumingMemoryBound(to: UInt8.self)) - ptr
        }
        return count
    }
}

// MARK: - Constants

private extension JSONLParser {
    enum Constants {
        static let assistantType = "assistant"
        static let syntheticModel = "<synthetic>"
        static let newlineByte: Int32 = 0x0A
    }
}

// MARK: - Supporting Types

private struct ValidatedUsageData {
    let message: JSONLUsageData.Message
    let usage: JSONLUsageData.Message.Usage
    let timestampStr: String
}

struct JSONLUsageData: Codable {
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