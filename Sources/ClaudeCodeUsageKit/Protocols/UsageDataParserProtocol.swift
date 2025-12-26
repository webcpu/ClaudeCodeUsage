//
//  UsageDataParserProtocol.swift
//  ClaudeCodeUsage
//
//  Protocol for parsing usage data (Single Responsibility Principle)
//

import Foundation

/// Protocol for parsing usage data from various formats
public protocol UsageDataParserProtocol {
    /// Parse a single line of JSONL into a usage entry
    func parseJSONLLine(_ line: String, projectPath: String) throws -> UsageEntry?
    
    /// Extract message ID from JSON data for deduplication
    func extractMessageId(from json: [String: Any]) -> String?
    
    /// Extract request ID from JSON data for deduplication
    func extractRequestId(from json: [String: Any]) -> String?
    
    /// Extract timestamp from JSON data for sorting
    func extractTimestamp(from json: [String: Any]) -> String?
}

/// Default JSONL parser implementation
public struct JSONLUsageParser: UsageDataParserProtocol {
    
    public init() {}
    
    public func parseJSONLLine(_ line: String, projectPath: String) throws -> UsageEntry? {
        guard !line.isEmpty,
              let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        // Look for messages with usage data
        guard let message = json["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any] else {
            return nil
        }
        
        let model = message["model"] as? String ?? "unknown"
        let inputTokens = usage["input_tokens"] as? Int ?? 0
        let outputTokens = usage["output_tokens"] as? Int ?? 0
        let cacheWriteTokens = usage["cache_creation_input_tokens"] as? Int ?? 0
        let cacheReadTokens = usage["cache_read_input_tokens"] as? Int ?? 0
        
        // Skip entries without meaningful token usage
        if inputTokens == 0 && outputTokens == 0 && cacheWriteTokens == 0 && cacheReadTokens == 0 {
            return nil
        }
        
        // Calculate cost if not provided
        var cost = json["costUSD"] as? Double ?? 0.0
        if cost == 0.0 && (inputTokens > 0 || outputTokens > 0) {
            if let pricing = ModelPricing.pricing(for: model) {
                cost = pricing.calculateCost(
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    cacheWriteTokens: cacheWriteTokens,
                    cacheReadTokens: cacheReadTokens
                )
            }
        }
        
        let timestamp = json["timestamp"] as? String ?? ""
        
        return UsageEntry(
            project: projectPath,
            timestamp: timestamp,
            model: model,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheWriteTokens: cacheWriteTokens,
            cacheReadTokens: cacheReadTokens,
            cost: cost,
            sessionId: json["sessionId"] as? String
        )
    }
    
    public func extractMessageId(from json: [String: Any]) -> String? {
        guard let message = json["message"] as? [String: Any] else { return nil }
        return message["id"] as? String
    }
    
    public func extractRequestId(from json: [String: Any]) -> String? {
        return json["requestId"] as? String
    }
    
    public func extractTimestamp(from json: [String: Any]) -> String? {
        return json["timestamp"] as? String
    }
}