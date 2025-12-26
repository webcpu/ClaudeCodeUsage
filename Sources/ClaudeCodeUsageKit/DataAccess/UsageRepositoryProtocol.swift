//
//  UsageRepositoryProtocol.swift
//  Protocol definition for usage data repository
//

import Foundation

/// Protocol for accessing usage data with dependency injection support
public protocol UsageRepositoryProtocol {
    /// Load usage entries for a specific date
    /// - Parameter date: The date to load entries for
    /// - Returns: Array of usage entries for the specified date
    /// - Throws: Repository errors if data loading fails
    func loadEntriesForDate(_ date: Date) async throws -> [UsageEntry]
}

/// Repository errors that can occur during data operations
public enum RepositoryError: Error, LocalizedError {
    case fileNotFound
    case invalidData
    case accessDenied
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Usage data file not found"
        case .invalidData:
            return "Invalid or corrupted usage data"
        case .accessDenied:
            return "Access denied to usage data directory"
        case .unknown:
            return "Unknown repository error occurred"
        }
    }
}

/// Extension to make existing UsageRepository conform to the protocol
extension UsageRepository: UsageRepositoryProtocol {
    public func loadEntriesForDate(_ date: Date) async throws -> [UsageEntry] {
        // Load all entries and filter by date
        let allEntries = try await getUsageEntries()
        
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        
        return allEntries.filter { entry in
            guard let entryDate = entry.date else { return false }
            let entryDay = calendar.startOfDay(for: entryDate)
            return entryDay == targetDay
        }
    }
}