import Foundation

// MARK: - Data Models

public struct TokenCounts: Sendable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationInputTokens: Int
    public let cacheReadInputTokens: Int
    
    public var total: Int {
        inputTokens + outputTokens + cacheCreationInputTokens + cacheReadInputTokens
    }
    
    public init(inputTokens: Int = 0, outputTokens: Int = 0, 
                cacheCreationInputTokens: Int = 0, cacheReadInputTokens: Int = 0) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
    }
}

public struct UsageEntry: Sendable {
    public let timestamp: Date
    public let usage: TokenCounts
    public let costUSD: Double
    public let model: String
    public let sourceFile: String
    public let messageId: String?
    public let requestId: String?
    public let usageLimitResetTime: Date?
    
    public init(timestamp: Date, usage: TokenCounts, costUSD: Double, model: String,
                sourceFile: String, messageId: String? = nil, requestId: String? = nil,
                usageLimitResetTime: Date? = nil) {
        self.timestamp = timestamp
        self.usage = usage
        self.costUSD = costUSD
        self.model = model
        self.sourceFile = sourceFile
        self.messageId = messageId
        self.requestId = requestId
        self.usageLimitResetTime = usageLimitResetTime
    }
}

public struct BurnRate: Sendable {
    public let tokensPerMinute: Int
    public let tokensPerMinuteForIndicator: Int
    public let costPerHour: Double
    
    public init(tokensPerMinute: Int, tokensPerMinuteForIndicator: Int, costPerHour: Double) {
        self.tokensPerMinute = tokensPerMinute
        self.tokensPerMinuteForIndicator = tokensPerMinuteForIndicator
        self.costPerHour = costPerHour
    }
}

public struct ProjectedUsage: Sendable {
    public let totalTokens: Int
    public let totalCost: Double
    public let remainingMinutes: Double
    
    public init(totalTokens: Int, totalCost: Double, remainingMinutes: Double) {
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.remainingMinutes = remainingMinutes
    }
}

public struct SessionBlock: Sendable {
    public let id: String
    public let startTime: Date
    public let endTime: Date
    public let actualEndTime: Date?
    public let isActive: Bool
    public let isGap: Bool
    public let entries: [UsageEntry]
    public let tokenCounts: TokenCounts
    public let costUSD: Double
    public let models: [String]
    public let usageLimitResetTime: Date?
    public let burnRate: BurnRate
    public let projectedUsage: ProjectedUsage
    
    public init(id: String, startTime: Date, endTime: Date, actualEndTime: Date?,
                isActive: Bool, isGap: Bool, entries: [UsageEntry], tokenCounts: TokenCounts,
                costUSD: Double, models: [String], usageLimitResetTime: Date?,
                burnRate: BurnRate, projectedUsage: ProjectedUsage) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.actualEndTime = actualEndTime
        self.isActive = isActive
        self.isGap = isGap
        self.entries = entries
        self.tokenCounts = tokenCounts
        self.costUSD = costUSD
        self.models = models
        self.usageLimitResetTime = usageLimitResetTime
        self.burnRate = burnRate
        self.projectedUsage = projectedUsage
    }
}

// MARK: - Model Pricing

public struct ModelPricing: Sendable {
    public let inputCostPerToken: Double
    public let outputCostPerToken: Double
    public let cacheCreationCostPerToken: Double
    public let cacheReadCostPerToken: Double
    
    // Default pricing for Claude models
    public static let claudeOpus4 = ModelPricing(
        inputCostPerToken: 0.000015,
        outputCostPerToken: 0.000075,
        cacheCreationCostPerToken: 0.00001875,
        cacheReadCostPerToken: 0.0000015
    )
    
    public static let claudeSonnet4 = ModelPricing(
        inputCostPerToken: 0.000003,
        outputCostPerToken: 0.000015,
        cacheCreationCostPerToken: 0.00000375,
        cacheReadCostPerToken: 0.0000003
    )
    
    public static func getPricing(for model: String) -> ModelPricing {
        if model.contains("opus") {
            return .claudeOpus4
        } else if model.contains("sonnet") {
            return .claudeSonnet4
        } else {
            // Default to Opus pricing for unknown models
            return .claudeOpus4
        }
    }
    
    public func calculateCost(tokens: TokenCounts) -> Double {
        return Double(tokens.inputTokens) * inputCostPerToken +
               Double(tokens.outputTokens) * outputCostPerToken +
               Double(tokens.cacheCreationInputTokens) * cacheCreationCostPerToken +
               Double(tokens.cacheReadInputTokens) * cacheReadCostPerToken
    }
    
    public init(inputCostPerToken: Double, outputCostPerToken: Double,
                cacheCreationCostPerToken: Double, cacheReadCostPerToken: Double) {
        self.inputCostPerToken = inputCostPerToken
        self.outputCostPerToken = outputCostPerToken
        self.cacheCreationCostPerToken = cacheCreationCostPerToken
        self.cacheReadCostPerToken = cacheReadCostPerToken
    }
}