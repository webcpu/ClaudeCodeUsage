//
//  UsageRepositoryError+Aggregator.swift
//
//  Error aggregation for batch operations.
//

import Foundation

// MARK: - Error Aggregator

/// Error aggregator for batch operations
public actor ErrorAggregator {
    private var errors: [Error] = []
    private let maxErrors: Int

    public init(maxErrors: Int = 100) {
        self.maxErrors = maxErrors
    }

    public func record(_ error: Error) {
        errors.append(error)
        if errors.count > maxErrors {
            errors.removeFirst()
        }
    }

    public func getErrors() -> [Error] {
        errors
    }

    public func getSummary() -> String {
        guard !errors.isEmpty else {
            return "No errors recorded"
        }
        return buildSummary(from: groupedErrorTypes)
    }

    public func clear() {
        errors.removeAll()
    }

    public func hasErrors() -> Bool {
        !errors.isEmpty
    }

    // MARK: - Summary Building Helpers

    private var groupedErrorTypes: [String: [Error]] {
        Dictionary(grouping: errors) { error in
            String(describing: type(of: error))
        }
    }

    private func buildSummary(from errorTypes: [String: [Error]]) -> String {
        let header = "Error Summary (\(errors.count) total):\n"
        let details = errorTypes
            .map { formatErrorType(name: $0.key, count: $0.value.count) }
            .joined()
        return header + details
    }

    private func formatErrorType(name: String, count: Int) -> String {
        "  \(name): \(count) occurrences\n"
    }
}
