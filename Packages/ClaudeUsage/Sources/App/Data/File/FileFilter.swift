//
//  FileFilter.swift
//  Composable predicates for filtering files
//

import Foundation

/// A composable predicate for filtering file metadata
public typealias FileFilter = @Sendable (FileMetadata) -> Bool

// MARK: - FileFilters (Factory Functions)

public enum FileFilters {

    /// Creates a filter for files modified today
    public static func modifiedToday(
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> FileFilter {
        let today = calendar.startOfDay(for: now)
        return { file in
            calendar.startOfDay(for: file.modificationDate) >= today
        }
    }

    /// Creates a filter for files modified within the specified hours
    public static func modifiedWithin(
        hours: Double,
        from now: Date = Date()
    ) -> FileFilter {
        let cutoff = now.addingTimeInterval(-hours * 3600)
        return { $0.modificationDate >= cutoff }
    }

    /// Creates a filter that matches all files (identity filter)
    public static var all: FileFilter {
        { _ in true }
    }

    /// Combines multiple filters with AND logic
    public static func all(_ filters: FileFilter...) -> FileFilter {
        { file in filters.allSatisfy { $0(file) } }
    }

    /// Combines multiple filters with OR logic
    public static func any(_ filters: FileFilter...) -> FileFilter {
        { file in filters.contains { $0(file) } }
    }

    /// Negates a filter
    public static func not(_ filter: @escaping FileFilter) -> FileFilter {
        { file in !filter(file) }
    }
}
