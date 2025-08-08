import Foundation

// MARK: - JSONL Data Structures

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

// MARK: - JSONL Parser

public struct JSONLParser {
    private let dateFormatter: ISO8601DateFormatter
    
    public init() {
        self.dateFormatter = ISO8601DateFormatter()
        self.dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }
    
    public func parseFile(at path: String, processedHashes: inout Set<String>) -> [UsageEntry] {
        var entries: [UsageEntry] = []
        
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return entries
        }
        
        for line in content.split(separator: "\n") {
            guard !line.isEmpty,
                  let data = line.data(using: .utf8) else {
                continue
            }
            
            do {
                let decoder = JSONDecoder()
                let usageData = try decoder.decode(JSONLUsageData.self, from: data)
                
                // Only process assistant messages with usage data
                guard let message = usageData.message,
                      let usage = message.usage,
                      usageData.type == "assistant",
                      let timestampStr = usageData.timestamp else {
                    continue
                }
                
                // Create unique hash for deduplication (matches ccusage exactly)
                if let messageId = message.id, let requestId = usageData.requestId {
                    let hash = "\(messageId):\(requestId)"
                    if processedHashes.contains(hash) {
                        continue
                    }
                    processedHashes.insert(hash)
                }
                
                // Parse timestamp
                guard let timestamp = dateFormatter.date(from: timestampStr) else {
                    continue
                }
                
                // Create token counts
                let tokenCounts = TokenCounts(
                    inputTokens: usage.input_tokens ?? 0,
                    outputTokens: usage.output_tokens ?? 0,
                    cacheCreationInputTokens: usage.cache_creation_input_tokens ?? 0,
                    cacheReadInputTokens: usage.cache_read_input_tokens ?? 0
                )
                
                // Skip entries with 0 tokens (ccusage filters these out)
                guard tokenCounts.total > 0 else {
                    continue
                }
                
                // Calculate cost from tokens if costUSD is not present
                let model = message.model ?? "<synthetic>"
                let cost: Double
                if let costUSD = usageData.costUSD {
                    cost = costUSD
                } else {
                    // Calculate cost based on model pricing
                    let pricing = ModelPricing.getPricing(for: model)
                    cost = pricing.calculateCost(tokens: tokenCounts)
                }
                
                let entry = UsageEntry(
                    timestamp: timestamp,
                    usage: tokenCounts,
                    costUSD: cost,
                    model: model,
                    sourceFile: path,
                    messageId: message.id,
                    requestId: usageData.requestId
                )
                
                entries.append(entry)
            } catch {
                continue
            }
        }
        
        return entries
    }
}