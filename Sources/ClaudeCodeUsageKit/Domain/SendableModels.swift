//
//  SendableModels.swift
//  Swift 6 Sendable conformance for thread-safe data types
//

import Foundation

// MARK: - Sendable Data Models

/// Thread-safe usage entry
public struct SendableUsageEntry: Codable, Sendable, Equatable {
    public let id: String
    public let timestamp: Date
    public let model: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int
    public let cost: Double
    public let projectPath: String?
    public let sessionId: String?
    
    public init(
        id: String = UUID().uuidString,
        timestamp: Date,
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int = 0,
        cacheReadTokens: Int = 0,
        cost: Double,
        projectPath: String? = nil,
        sessionId: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
        self.cost = cost
        self.projectPath = projectPath
        self.sessionId = sessionId
    }
    
    public var totalTokens: Int {
        inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }
}

/// Thread-safe usage statistics
public struct SendableUsageStats: Sendable, Equatable {
    public let totalCost: Double
    public let totalTokens: Int
    public let totalInputTokens: Int
    public let totalOutputTokens: Int
    public let totalCacheCreationTokens: Int
    public let totalCacheReadTokens: Int
    public let totalSessions: Int
    public let byModel: [ModelUsage]
    public let byDate: [DailyUsage]
    public let byProject: [ProjectUsage]
    public let dateRange: DateRange?
    
    public init(
        totalCost: Double = 0,
        totalTokens: Int = 0,
        totalInputTokens: Int = 0,
        totalOutputTokens: Int = 0,
        totalCacheCreationTokens: Int = 0,
        totalCacheReadTokens: Int = 0,
        totalSessions: Int = 0,
        byModel: [ModelUsage] = [],
        byDate: [DailyUsage] = [],
        byProject: [ProjectUsage] = [],
        dateRange: DateRange? = nil
    ) {
        self.totalCost = totalCost
        self.totalTokens = totalTokens
        self.totalInputTokens = totalInputTokens
        self.totalOutputTokens = totalOutputTokens
        self.totalCacheCreationTokens = totalCacheCreationTokens
        self.totalCacheReadTokens = totalCacheReadTokens
        self.totalSessions = totalSessions
        self.byModel = byModel
        self.byDate = byDate
        self.byProject = byProject
        self.dateRange = dateRange
    }
    
    public struct ModelUsage: Sendable, Equatable {
        public let model: String
        public let totalCost: Double
        public let totalTokens: Int
        public let sessionCount: Int
        
        public init(model: String, totalCost: Double, totalTokens: Int, sessionCount: Int) {
            self.model = model
            self.totalCost = totalCost
            self.totalTokens = totalTokens
            self.sessionCount = sessionCount
        }
    }
    
    public struct DailyUsage: Sendable, Equatable {
        public let date: String
        public let totalCost: Double
        public let totalTokens: Int
        public let modelsUsed: [String]
        
        public init(date: String, totalCost: Double, totalTokens: Int, modelsUsed: [String]) {
            self.date = date
            self.totalCost = totalCost
            self.totalTokens = totalTokens
            self.modelsUsed = modelsUsed
        }
    }
    
    public struct ProjectUsage: Sendable, Equatable {
        public let projectName: String
        public let totalCost: Double
        public let totalTokens: Int
        public let lastUsed: Date
        
        public init(projectName: String, totalCost: Double, totalTokens: Int, lastUsed: Date) {
            self.projectName = projectName
            self.totalCost = totalCost
            self.totalTokens = totalTokens
            self.lastUsed = lastUsed
        }
    }
    
    public struct DateRange: Sendable, Equatable {
        public let start: Date
        public let end: Date
        
        public init(start: Date, end: Date) {
            self.start = start
            self.end = end
        }
    }
}

// MARK: - Session Models

/// Thread-safe session block
public struct SendableSessionBlock: Sendable, Equatable {
    public let id: String
    public let startTime: Date
    public let endTime: Date?
    public let model: String
    public let tokenCounts: TokenCounts
    public let costUSD: Double
    public let projectPath: String?
    
    public init(
        id: String = UUID().uuidString,
        startTime: Date,
        endTime: Date? = nil,
        model: String,
        tokenCounts: TokenCounts,
        costUSD: Double,
        projectPath: String? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.model = model
        self.tokenCounts = tokenCounts
        self.costUSD = costUSD
        self.projectPath = projectPath
    }
    
    public struct TokenCounts: Sendable, Equatable {
        public let input: Int
        public let output: Int
        public let cacheCreation: Int
        public let cacheRead: Int
        
        public init(
            input: Int = 0,
            output: Int = 0,
            cacheCreation: Int = 0,
            cacheRead: Int = 0
        ) {
            self.input = input
            self.output = output
            self.cacheCreation = cacheCreation
            self.cacheRead = cacheRead
        }
        
        public var total: Int {
            input + output + cacheCreation + cacheRead
        }
    }
    
    public var duration: TimeInterval {
        guard let endTime = endTime else {
            return Date().timeIntervalSince(startTime)
        }
        return endTime.timeIntervalSince(startTime)
    }
    
    public var isActive: Bool {
        endTime == nil
    }
}

/// Thread-safe burn rate
public struct SendableBurnRate: Sendable, Equatable {
    public let tokensPerMinute: Int
    public let costPerHour: Double
    public let projectedDailyCost: Double
    
    public init(
        tokensPerMinute: Int,
        costPerHour: Double,
        projectedDailyCost: Double
    ) {
        self.tokensPerMinute = tokensPerMinute
        self.costPerHour = costPerHour
        self.projectedDailyCost = projectedDailyCost
    }
}

// MARK: - Chart Data Models

/// Thread-safe chart data point
public struct SendableChartPoint: Sendable, Equatable, Identifiable {
    public let id = UUID()
    public let date: Date
    public let value: Double
    public let label: String
    
    public init(date: Date, value: Double, label: String = "") {
        self.date = date
        self.value = value
        self.label = label
    }
}

/// Thread-safe chart dataset
public struct SendableChartDataset: Sendable, Equatable {
    public let points: [SendableChartPoint]
    public let title: String
    public let color: String
    
    public init(points: [SendableChartPoint], title: String, color: String = "blue") {
        self.points = points
        self.title = title
        self.color = color
    }
    
    public var isEmpty: Bool {
        points.isEmpty
    }
    
    public var totalValue: Double {
        points.reduce(0) { $0 + $1.value }
    }
}

// MARK: - Configuration Models

/// Thread-safe app configuration
public struct SendableAppConfiguration: Sendable, Equatable {
    public let basePath: String
    public let refreshInterval: TimeInterval
    public let sessionDurationHours: Double
    public let dailyCostThreshold: Double
    public let minimumRefreshInterval: TimeInterval
    public let enableAutoRefresh: Bool
    public let enableNotifications: Bool
    
    public init(
        basePath: String,
        refreshInterval: TimeInterval = 30.0,
        sessionDurationHours: Double = 5.0,
        dailyCostThreshold: Double = 10.0,
        minimumRefreshInterval: TimeInterval = 5.0,
        enableAutoRefresh: Bool = true,
        enableNotifications: Bool = false
    ) {
        self.basePath = basePath
        self.refreshInterval = refreshInterval
        self.sessionDurationHours = sessionDurationHours
        self.dailyCostThreshold = dailyCostThreshold
        self.minimumRefreshInterval = minimumRefreshInterval
        self.enableAutoRefresh = enableAutoRefresh
        self.enableNotifications = enableNotifications
    }
}

// MARK: - Request/Response Models

/// Thread-safe data request
public struct SendableDataRequest: Sendable {
    public let dateRange: SendableUsageStats.DateRange?
    public let projectFilter: String?
    public let modelFilter: String?
    public let limit: Int?
    
    public init(
        dateRange: SendableUsageStats.DateRange? = nil,
        projectFilter: String? = nil,
        modelFilter: String? = nil,
        limit: Int? = nil
    ) {
        self.dateRange = dateRange
        self.projectFilter = projectFilter
        self.modelFilter = modelFilter
        self.limit = limit
    }
}

/// Thread-safe data response
public struct SendableDataResponse<T: Sendable>: Sendable {
    public let data: T
    public let timestamp: Date
    public let cached: Bool
    
    public init(data: T, timestamp: Date = Date(), cached: Bool = false) {
        self.data = data
        self.timestamp = timestamp
        self.cached = cached
    }
}