//
//  DateProviding.swift
//  Protocol for testable date provision
//

import Foundation

/// Protocol for providing current date/time, enabling deterministic testing
public protocol DateProviding: Sendable {
    var now: Date { get }
    func startOfDay(for date: Date) -> Date
}

/// Default implementation using system date
public struct SystemDateProvider: DateProviding {
    public init() {}
    
    public var now: Date {
        Date()
    }
    
    public func startOfDay(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}

/// Test implementation with fixed date
public struct TestDateProvider: DateProviding {
    public let fixedDate: Date
    private let calendar: Calendar
    
    public init(fixedDate: Date, calendar: Calendar = .current) {
        self.fixedDate = fixedDate
        self.calendar = calendar
    }
    
    public var now: Date {
        fixedDate
    }
    
    public func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }
}