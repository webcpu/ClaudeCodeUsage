import Foundation

// MARK: - Message Type Validation Protocol

/// Protocol defining message type validation behavior.
/// Conform to this protocol to add support for new message types.
public protocol MessageTypeValidator: Sendable {
    /// The message type this validator handles (e.g., "assistant", "user")
    var messageType: String { get }

    /// Validates the raw data and extracts validated components
    func validate(_ raw: RawJSONLData) -> ValidatedData?
}

// MARK: - Message Type Validator Registry

/// Registry of message type validators.
/// Open for extension: register new validators at app startup.
public final class MessageTypeValidatorRegistry: @unchecked Sendable {
    public static let shared = MessageTypeValidatorRegistry()

    private var validators: [MessageTypeValidator] = [
        AssistantMessageValidator()
    ]

    private init() {}

    /// Register a new validator for a message type
    public func register(_ validator: MessageTypeValidator) {
        validators.append(validator)
    }

    /// Finds and applies the appropriate validator for the given data
    public func validate(_ raw: RawJSONLData) -> ValidatedData? {
        guard let type = raw.type else { return nil }
        return validators.first { $0.messageType == type }?.validate(raw)
    }
}

// MARK: - Composed Validation Function

/// Composable validation function using the shared registry
public let validateMessageType: @Sendable (RawJSONLData) -> ValidatedData? = { raw in
    MessageTypeValidatorRegistry.shared.validate(raw)
}

// MARK: - Assistant Message Validator

/// Validator for assistant-type messages containing usage data
public struct AssistantMessageValidator: MessageTypeValidator {
    public let messageType = "assistant"

    public init() {}

    public func validate(_ raw: RawJSONLData) -> ValidatedData? {
        guard raw.type == messageType,
              let message = raw.message,
              let usage = message.usage,
              let timestampStr = raw.timestamp else {
            return nil
        }
        return ValidatedData(message: message, usage: usage, timestampStr: timestampStr)
    }
}

// MARK: - JSONLParser

public struct JSONLParser: Sendable {

    // MARK: - Constants

    private enum ByteValue {
        static let newline: Int32 = 0x0A
    }

    private enum DefaultValue {
        static let syntheticModel = "<synthetic>"
    }

    // MARK: - Static Configuration

    nonisolated(unsafe) private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    // MARK: - Initialization

    public init() {}

    // MARK: - Public API

    public func parseFile(
        at path: String,
        project: String,
        processedHashes: inout Set<String>
    ) -> [UsageEntry] {
        guard let fileData = loadFileData(at: path) else { return [] }
        return extractLines(from: fileData)
            .compactMap { parseEntry(from: $0, path: path, project: project, processedHashes: &processedHashes) }
    }

    // MARK: - Entry Parsing

    private func parseEntry(
        from lineData: Data,
        path: String,
        project: String,
        processedHashes: inout Set<String>
    ) -> UsageEntry? {
        guard let rawData = decodeRawData(from: lineData),
              let validated = validateMessage(rawData),
              isUniqueEntry(rawData, validated, processedHashes: &processedHashes),
              let timestamp = parseTimestamp(validated.timestampStr) else {
            return nil
        }

        return buildUsageEntry(
            from: rawData,
            validated: validated,
            timestamp: timestamp,
            project: project,
            path: path
        )
    }

    private func buildUsageEntry(
        from rawData: RawJSONLData,
        validated: ValidatedData,
        timestamp: Date,
        project: String,
        path: String
    ) -> UsageEntry? {
        let tokens = createTokenCounts(from: validated.usage)
        guard hasTokenUsage(tokens) else { return nil }

        let model = validated.message.model ?? DefaultValue.syntheticModel
        let cost = rawData.costUSD ?? PricingCalculator.calculateCost(tokens: tokens, model: model)

        return UsageEntry(
            id: createEntryId(validated.message.id, rawData.requestId, timestamp),
            timestamp: timestamp,
            model: model,
            tokens: tokens,
            costUSD: cost,
            project: project,
            sourceFile: path,
            sessionId: rawData.sessionId,
            messageId: validated.message.id,
            requestId: rawData.requestId
        )
    }

    // MARK: - Validation

    private func validateMessage(_ raw: RawJSONLData) -> ValidatedData? {
        validateMessageType(raw)
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

    private func hasTokenUsage(_ tokens: TokenCounts) -> Bool {
        tokens.total > 0
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

    // MARK: - File I/O

    private func loadFileData(at path: String) -> Data? {
        try? Data(contentsOf: URL(fileURLWithPath: path))
    }

    private func extractLines(from data: Data) -> [Data] {
        guard !data.isEmpty else { return [] }
        return [UInt8](data).withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return [] }
            return findLineRanges(in: baseAddress, count: data.count)
                .map { data[$0] }
        }
    }

    // MARK: - Decoding

    private func decodeRawData(from lineData: Data) -> RawJSONLData? {
        guard !lineData.isEmpty else { return nil }
        return try? JSONDecoder().decode(RawJSONLData.self, from: lineData)
    }

    // MARK: - Line Extraction

    private func findLineRanges(in ptr: UnsafePointer<UInt8>, count: Int) -> [Range<Data.Index>] {
        sequence(state: 0) { offset -> Range<Data.Index>? in
            guard offset < count else { return nil }
            let lineEnd = findLineEnd(in: ptr, from: offset, count: count)
            let range = offset..<lineEnd
            offset = lineEnd + 1
            return range
        }
        .filter { !$0.isEmpty }
    }

    private func findLineEnd(in ptr: UnsafePointer<UInt8>, from offset: Int, count: Int) -> Int {
        let remaining = count - offset
        guard let found = memchr(ptr + offset, ByteValue.newline, remaining) else {
            return count
        }
        return UnsafePointer(found.assumingMemoryBound(to: UInt8.self)) - ptr
    }
}

// MARK: - Raw JSONL Data Model

public struct RawJSONLData: Codable, Sendable {
    public let timestamp: String?
    public let message: Message?
    public let costUSD: Double?
    public let type: String?
    public let requestId: String?
    public let sessionId: String?

    public struct Message: Codable, Sendable {
        public let usage: Usage?
        public let model: String?
        public let id: String?

        public struct Usage: Codable, Sendable {
            public let input_tokens: Int?
            public let output_tokens: Int?
            public let cache_creation_input_tokens: Int?
            public let cache_read_input_tokens: Int?
        }
    }
}

// MARK: - Validated Data

public struct ValidatedData: Sendable {
    public let message: RawJSONLData.Message
    public let usage: RawJSONLData.Message.Usage
    public let timestampStr: String

    public init(message: RawJSONLData.Message, usage: RawJSONLData.Message.Usage, timestampStr: String) {
        self.message = message
        self.usage = usage
        self.timestampStr = timestampStr
    }
}
