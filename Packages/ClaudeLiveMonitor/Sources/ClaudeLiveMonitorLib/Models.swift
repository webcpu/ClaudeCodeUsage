import Foundation

// MARK: - TokenCounts

public struct TokenCounts: Sendable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationInputTokens: Int
    public let cacheReadInputTokens: Int

    public var total: Int {
        inputTokens + outputTokens + cacheCreationInputTokens + cacheReadInputTokens
    }

    public init(
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        cacheCreationInputTokens: Int = 0,
        cacheReadInputTokens: Int = 0
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
    }
}

// MARK: - UsageEntry

public struct UsageEntry: Sendable {
    public let timestamp: Date
    public let usage: TokenCounts
    public let costUSD: Double
    public let model: String
    public let sourceFile: String
    public let messageId: String?
    public let requestId: String?
    public let usageLimitResetTime: Date?

    public init(
        timestamp: Date,
        usage: TokenCounts,
        costUSD: Double,
        model: String,
        sourceFile: String,
        messageId: String? = nil,
        requestId: String? = nil,
        usageLimitResetTime: Date? = nil
    ) {
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

// MARK: - BurnRate

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

// MARK: - ProjectedUsage

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

// MARK: - SessionBlock

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

    public init(
        id: String,
        startTime: Date,
        endTime: Date,
        actualEndTime: Date?,
        isActive: Bool,
        isGap: Bool,
        entries: [UsageEntry],
        tokenCounts: TokenCounts,
        costUSD: Double,
        models: [String],
        usageLimitResetTime: Date?,
        burnRate: BurnRate,
        projectedUsage: ProjectedUsage
    ) {
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

// MARK: - ModelPricing

public struct ModelPricing: Sendable {
    public let inputCostPerToken: Double
    public let outputCostPerToken: Double
    public let cacheCreationCostPerToken: Double
    public let cacheReadCostPerToken: Double

    public init(
        inputCostPerToken: Double,
        outputCostPerToken: Double,
        cacheCreationCostPerToken: Double,
        cacheReadCostPerToken: Double
    ) {
        self.inputCostPerToken = inputCostPerToken
        self.outputCostPerToken = outputCostPerToken
        self.cacheCreationCostPerToken = cacheCreationCostPerToken
        self.cacheReadCostPerToken = cacheReadCostPerToken
    }

    public func calculateCost(tokens: TokenCounts) -> Double {
        inputCost(for: tokens) + outputCost(for: tokens) + cacheCost(for: tokens)
    }
}

// MARK: - ModelPricing Pricing Configurations

public extension ModelPricing {
    static let claudeOpus4 = ModelPricing(
        inputCostPerToken: 0.000015,
        outputCostPerToken: 0.000075,
        cacheCreationCostPerToken: 0.00001875,
        cacheReadCostPerToken: 0.0000015
    )

    static let claudeSonnet4 = ModelPricing(
        inputCostPerToken: 0.000003,
        outputCostPerToken: 0.000015,
        cacheCreationCostPerToken: 0.00000375,
        cacheReadCostPerToken: 0.0000003
    )

    static let `default` = claudeOpus4
}

// MARK: - ModelPricing Lookup

public extension ModelPricing {
    static func getPricing(for model: String) -> ModelPricing {
        ModelFamily(from: model).pricing
    }
}

// MARK: - ModelPricing Cost Calculation

private extension ModelPricing {
    func inputCost(for tokens: TokenCounts) -> Double {
        Double(tokens.inputTokens) * inputCostPerToken
    }

    func outputCost(for tokens: TokenCounts) -> Double {
        Double(tokens.outputTokens) * outputCostPerToken
    }

    func cacheCost(for tokens: TokenCounts) -> Double {
        cacheCreationCost(for: tokens) + cacheReadCost(for: tokens)
    }

    func cacheCreationCost(for tokens: TokenCounts) -> Double {
        Double(tokens.cacheCreationInputTokens) * cacheCreationCostPerToken
    }

    func cacheReadCost(for tokens: TokenCounts) -> Double {
        Double(tokens.cacheReadInputTokens) * cacheReadCostPerToken
    }
}

// MARK: - ModelFamily

private enum ModelFamily {
    case opus
    case sonnet
    case unknown

    init(from modelName: String) {
        self = Self.allKnownFamilies.first { $0.matches(modelName) } ?? .unknown
    }

    var pricing: ModelPricing {
        switch self {
        case .opus: .claudeOpus4
        case .sonnet: .claudeSonnet4
        case .unknown: .default
        }
    }
}

// MARK: - ModelFamily Matching

private extension ModelFamily {
    static let allKnownFamilies: [ModelFamily] = [.opus, .sonnet]

    var identifier: String {
        switch self {
        case .opus: "opus"
        case .sonnet: "sonnet"
        case .unknown: ""
        }
    }

    func matches(_ modelName: String) -> Bool {
        modelName.lowercased().contains(identifier)
    }
}
