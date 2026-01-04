//
//  FileWriter.swift
//  Protocol for file system operations. This is the boundary between
//  pure functional code and impure I/O.
//

import Foundation

// MARK: - Protocol

/// Protocol for file system operations.
/// This is the "impure shell" boundary for file I/O.
public protocol FileWriting: Sendable {
    /// Creates a directory at the specified URL.
    ///
    /// - Parameter url: The directory URL to create
    /// - Throws: File system errors
    func createDirectory(at url: URL) throws

    /// Writes data to a file.
    ///
    /// - Parameters:
    ///   - data: The data to write
    ///   - url: The file URL to write to
    /// - Throws: File system errors
    func write(_ data: Data, to url: URL) throws
}

// MARK: - Default Implementation

/// Default FileWriter using FileManager.
/// This is the production implementation that performs actual file I/O.
public struct FileSystemWriter: FileWriting {
    public init() {}

    public func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    public func write(_ data: Data, to url: URL) throws {
        try data.write(to: url)
    }
}

// MARK: - Mock Implementation

/// Mock FileWriter for testing.
/// Records operations without performing actual I/O.
public final class MockFileWriter: FileWriting, @unchecked Sendable {
    private let lock = NSLock()
    private var _createdDirectories: [URL] = []
    private var _writtenFiles: [(url: URL, data: Data)] = []
    private var shouldThrow: Error?

    public init() {}

    /// Configure the mock to throw an error on all operations.
    public func throwOnWrite(_ error: Error) {
        lock.lock()
        defer { lock.unlock() }
        shouldThrow = error
    }

    public func createDirectory(at url: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        if let error = shouldThrow { throw error }
        _createdDirectories.append(url)
    }

    public func write(_ data: Data, to url: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        if let error = shouldThrow { throw error }
        _writtenFiles.append((url: url, data: data))
    }

    /// Returns all directories that were created.
    public var createdDirectories: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return _createdDirectories
    }

    /// Returns all files that were written.
    public var writtenFiles: [(url: URL, data: Data)] {
        lock.lock()
        defer { lock.unlock() }
        return _writtenFiles
    }

    /// Clears all recorded operations.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        _createdDirectories.removeAll()
        _writtenFiles.removeAll()
        shouldThrow = nil
    }
}

// MARK: - Recording Writer

/// A wrapper that records all operations while delegating to another writer.
/// Useful for verification in integration tests.
public final class RecordingFileWriter: FileWriting, @unchecked Sendable {
    private let wrapped: FileWriting
    private let lock = NSLock()
    private var _createdDirectories: [URL] = []
    private var _writtenFiles: [URL] = []

    public init(wrapping writer: FileWriting) {
        self.wrapped = writer
    }

    public func createDirectory(at url: URL) throws {
        try wrapped.createDirectory(at: url)
        lock.lock()
        defer { lock.unlock() }
        _createdDirectories.append(url)
    }

    public func write(_ data: Data, to url: URL) throws {
        try wrapped.write(data, to: url)
        lock.lock()
        defer { lock.unlock() }
        _writtenFiles.append(url)
    }

    /// Returns all directories that were created.
    public var createdDirectories: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return _createdDirectories
    }

    /// Returns all files that were written.
    public var writtenFiles: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return _writtenFiles
    }
}
